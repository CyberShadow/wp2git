// Written in the D Programming Language (version 2)

import std.stdio;
import std.process;
import std.stream;
import std.string;
import std.file;
import std.conv;
import std.uri;
import std.getopt;
import std.exception;

import ae.utils.xmllite;

int main(string[] args)
{
	string name, language="en";
	bool usage, noImport;
	getopt(args,
		"h|help", &usage,
		"no-import", &noImport,
		"language", &language,
	);

	enforce(args.length<=2, "Multiple article name arguments");
	if (args.length == 1 || usage)
	{
		stderr.writefln("Usage: %s Article_name [OPTION]...", args[0]);
		stderr.writefln("Create a git repository with the history of the specified Wikipedia article.");
		stderr.writefln("Supported options:");
		stderr.writefln(" -h  --help		Display this help");
		stderr.writefln("     --no-import	Don't invoke ``git fast-import'' and only generate the fast-import data");
		stderr.writefln("     --language LANG	Specify the Wikipedia language subdomain (default: en)");
		return 2;
	}

	if (!name)
		throw new Exception("No article specified");

	if (name.length>=2 && name[0]=='"' && name[$-1]=='"')
		name = name[1..$-1]; // strip quotes

	if (spawnvp(P_WAIT, "curl", ["curl", "-d", "\"\"", "http://" ~ language ~ ".wikipedia.org/w/index.php?title=Special:Export&pages=" ~ encodeComponent(name), "-o", "history.xml"]))
		throw new Exception("curl error");

	stderr.writefln("Loading history...");
	string xmldata = cast(string) read("history.xml");
	std.file.remove("history.xml");
	auto xml = new XmlDocument(xmldata);

	string data = "reset refs/heads/master\n";
	auto page = xml[0]["page"];
	if (!page)
		throw new Exception("No such page");
	foreach (child; page)
		if (child.tag=="revision")
		{
			string id = child["id"].text;
			string summary = child.findChild("comment") ? child["comment"].text : null;
			string committer = child["contributor"].findChild("username") ? child["contributor"]["username"].text : child["contributor"]["ip"].text;
			string text = child["text"].text;
			stderr.writefln("Revision %s by %s: %s", id, committer, summary);
			
			summary ~= "\n\nhttp://" ~ language ~ ".wikipedia.org/w/index.php?oldid=" ~ id;
			data ~= 
				"commit refs/heads/master\n" ~ 
				"committer " ~ committer ~ " <" ~ committer ~ "@" ~ language ~ ".wikipedia.org> " ~ ISO8601toRFC2822(child["timestamp"].text) ~ "\n" ~ 
				"data " ~ to!string(summary.length) ~ "\n" ~ 
				summary ~ "\n" ~ 
				"M 644 inline " ~ name ~ ".txt\n" ~ 
				"data " ~ to!string(text.length) ~ "\n" ~ 
				text ~ "\n" ~ 
				"\n";
		}
	std.file.write("fast-import-data", data);

	if (noImport)
		return 0;

	if (exists(".git"))
		throw new Exception("A git repository already exists here!");
	
	system("git init");
	system("git fast-import --date-format=rfc2822 < fast-import-data");
	std.file.remove("fast-import-data");
	system("git reset --hard");

	return 0;
}

string ISO8601toRFC2822(string s)
{
	const monthNames = ["Jan", "Feb", "Mar", "Apr", "May", "Jun", "Jul", "Aug", "Sep", "Oct", "Nov", "Dec"];
	
	// 2010-06-15T19:28:44Z
	// Feb 6 11:22:18 2007 -0500
	return monthNames[.to!int(s[5..7])-1] ~ " " ~ s[8..10] ~ " " ~ s[11..13] ~ ":" ~ s[14..16] ~ ":" ~ s[17..19] ~ " " ~ s[0..4] ~ " +0000";
}
