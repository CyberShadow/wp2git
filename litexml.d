/**
 * Light read-only XML library
 *
 * Copyright 2008, 2009  Vladimir Panteleev <thecybershadow@gmail.com>
 */

module litexml;

import std.stream;
import std.string;
import std.ctype;

alias std.string.iswhite iswhite;
alias std.string.tolower tolower;

enum XmlNodeType
{
	Root,
	Node,
	//Comment,
	Meta,
	Text
}

class XmlNode
{
	string tag;
	string[string] attributes;
	XmlNode[] children;
	XmlNodeType type;
	
	this(Stream s)
	{
	again:	
		char c;
		do
			s.read(c);
		while(iswhite(c));
		
		if(c!='<')  // text node
		{
			type = XmlNodeType.Text;
			while(c!='<')
			{
				// TODO: check for EOF
				tag ~= c;
				s.read(c);
			}
			s.seekCur(-1); // rewind to '<'
			//tag = tag.strip();
		}
		else
		{
			s.read(c);
			if(c=='!') // comment
			{
				expect(s, '-');
				expect(s, '-');
				char c1, c2, c3;
				do
				{
					c1 = c2; c2 = c3; s.read(c3);
				} while (!(c1=='-' && c2=='-' && c3=='>'));
				goto again;
			}
			else
			if(c=='?')
			{
				type = XmlNodeType.Meta;
				tag=readWord(s);
				if(tag.length==0) throw new Exception("Invalid tag");
				while(true)
				{
					skipWhitespace(s);
					if(peek(s)=='?')
						break;
					readAttribute(s);
				}
				s.read(c);
				expect(s, '>');
			}
			else
			if(c=='/')
				throw new Exception("Unexpected close tag");
			else
			{
				type = XmlNodeType.Node;
				tag = c~readWord(s);
				while(true)
				{
					skipWhitespace(s);
					c = peek(s);
					if(c=='>' || c=='/')
						break;
					readAttribute(s);
				}
				s.read(c);
				if(c=='>')
				{
					while(true)
					{
						skipWhitespace(s);
						if(peek(s)=='<' && peek(s, 2)=='/')
							break;
						try
							children ~= new XmlNode(s);
						catch(Object e)
							throw new Exception("Error while processing child of "~tag~":\n"~e.toString);
					}
					expect(s, '<');
					expect(s, '/');
					foreach(tc;tag)
						expect(s, tc);
					expect(s, '>');
				}
				else
					expect(s, '>');
			}
		}
	}

	string toString()
	{
		switch(type)
		{
			case XmlNodeType.Text:
				// TODO: compact whitespace
				return '"' ~ convertEntities(tag) ~ '"';
			case XmlNodeType.Node:
			case XmlNodeType.Root:
				string attrText;
				foreach(key,value;attributes)
					attrText ~= ' ' ~ key ~ `="` ~ value ~ '"';
				string childrenText;
				foreach(child;children)
					childrenText ~= child.toString();
				return '<' ~ tag ~ attrText ~ '>' ~ childrenText ~ "</" ~ tag ~ '>';
			default:
				return null;
		}
	}
	
	string text()
	{
		switch(type)
		{
			case XmlNodeType.Text:
				return convertEntities(tag);
			case XmlNodeType.Node:
			case XmlNodeType.Root:
				string childrenText;
				foreach(child;children)
					childrenText ~= child.text();
				return childrenText;
			default:
				return null;
		}
	}
	
	final XmlNode findChild(string tag)
	{
		foreach(child;children)
			if(child.tag == tag)
				return child;
		return null;
	}

	final XmlNode opIndex(string tag)
	{
		return findChild(tag);
	}

	final XmlNode opIndex(int index)
	{
		return children[index];
	}

	int opApply(int delegate(ref XmlNode) dg)
	{   
		int result = 0;

		for (int i = 0; i < children.length; i++)
		{
			result = dg(children[i]);
			if (result)
				break;
		}
		return result;
	}

private:
	final void readAttribute(Stream s)
	{
		string name = readWord(s);
		if(name.length==0) throw new Exception("Invalid attribute");
		skipWhitespace(s);
		expect(s, '=');
		skipWhitespace(s);
		char delim;
		s.read(delim);
		if(delim != '\'' && delim != '"')
			throw new Exception("Expected ' or \'");
		string value;
		while(true)
		{
			char c;
			s.read(c);
			if(c==delim) break;
			value ~= c;
		}
		attributes[name]=value;
	}

	this()
	{
	}
}

class XmlDocument : XmlNode
{
	this(Stream s)
	{
		type = XmlNodeType.Root;
		tag = "<Root>";
	    skipWhitespace(s);
		while(s.position < s.size)
			try
			{
				children ~= new XmlNode(s);
				skipWhitespace(s);
			}
			catch(Object o)
				break;
	}
}

private:

char peek(Stream s, int n=1)
{
	char c;
	for(int i=0;i<n;i++)
		s.read(c);
	s.seekCur(-n);
	return c;
}

void skipWhitespace(Stream s)
{
	char c;
	do
	{
		if(s.position==s.size)
			return;
		s.read(c);
	}
	while(iswhite(c));
	s.seekCur(-1);
}

bool isWord(char c)
{
	return c=='-' || c=='_' || c==':' || isalnum(c);
}

string readWord(Stream s)
{
	char c;
	string result;
	while(true)
	{
		s.read(c);
		if(!isWord(c))
			break;
		result ~= c;
	}
	s.seekCur(-1);
	return result;
}

void expect(Stream s, char c)
{
	char c2;
	s.read(c2);
	if(c!=c2)
		throw new Exception("Expected " ~ c ~ ", got " ~ c2);
}

const string[string] entities;
static this()
{
	entities = 
	[
		"quot"[]: \&quot;[],
		"amp"   : \&amp;   ,
		"lt"    : \&lt;    ,
		"gt"    : \&gt;    ,
		"circ"  : \&circ;  ,
		"tilde" : \&tilde; ,
		"nbsp"  : \&nbsp;  ,		
		"ensp"  : \&ensp;  ,
		"emsp"  : \&emsp;  ,
		"thinsp": \&thinsp;,
		"ndash" : \&ndash; ,
		"mdash" : \&mdash; ,
		"lsquo" : \&lsquo; ,
		"rsquo" : \&rsquo; ,
//		"sbquo" : \&sbquo; ,
		"ldquo" : \&ldquo; ,
		"rdquo" : \&rdquo; ,
//		"bdquo" : \&bdquo; ,
		"dagger": \&dagger;,
		"Dagger": \&Dagger;,
		"permil": \&permil;
//		"lsaquo": \&lsaquo;,
//		"rsaquo": \&rsaquo;,
//		"euro"  : \&euro;
	];
}

import std.utf;
import std.c.stdio;

public string convertEntities(string source)
{
	mainLoop:
	dstring str = toUTF32(source);
	for(int i=0;i<str.length;i++)
	{
		if(str[i]=='&')
			for(int j=i+1;j<str.length;j++)
				if(str[j]==';')
				{
					string entity = toUTF8(str[i+1..j]);
					if(entity.length>0)
						if(entity[0]=='#')
							if(entity.length>1 && entity[1]=='x')
							{
								dchar c;
								sscanf(toStringz(entity[2..$]), "%x", &c);
								if(c)
									str = str[0..i] ~ c ~ str[j+1..$];
							}
							else
							{
								dchar c;
								sscanf(toStringz(entity[1..$]), "%d", &c);
								if(c)
									str = str[0..i] ~ c ~ str[j+1..$];
							}
						else
							if(entity in entities)
								str = str[0..i] ~ toUTF32(entities[entity]) ~ str[j+1..$];
					break;
				}
	}
	return toUTF8(str);
}
