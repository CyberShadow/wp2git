import std.stdio;
import std.process;
import std.stream;
import std.string;
import std.file;
import litexml;

int main(string[] args)
{
	if (args.length != 2)
	{
		fwritefln(stderr, "Usage: %s Article_name", args[0]);
		return 1;
	}

	string name = args[1];
	if (name.length>=2 && name[0]=='"' && name[$-1]=='"')
		name = name[1..$-1]; // strip quotes

	if (spawnvp(P_WAIT, "curl", ["curl", "-d", "\"\"", "http://en.wikipedia.org/w/index.php?title=Special:Export&pages=" ~ name, "-o", "history.xml"]))
		throw new Exception("curl error");

	fwritefln(stderr, "Loading history...");
	auto xml = new XmlDocument(new File("history.xml"));

	string data;
	foreach (child; xml[0]["page"])
		if (child.tag=="revision")
		{
			fwritefln(stderr, "Revision %s", child["id"].text);
			string summary = child["comment"] ? child["comment"].text : null;
			string text = child["text"].text;
			data ~= 
				"commit master\n" ~ 
				"committer <" ~ (child["contributor"]["username"] ? child["contributor"]["username"].text : child["contributor"]["ip"].text) ~ "> now\n" ~ 
				"data " ~ .toString(summary.length) ~ "\n" ~ 
				summary ~ "\n" ~ 
				"M 644 inline " ~ name ~ ".txt\n" ~ 
				"data " ~ .toString(text.length) ~ "\n" ~ 
				text ~ "\n" ~ 
				"\n";
		}
	write("fast-import-data", data);
	return 0;
}
