import std.stdio;
import std.process;
import std.stream;
import std.string;
import std.file;
import std.conv;
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
	string xmldata = cast(string) read("history.xml");
	std.file.remove("history.xml");
	auto xml = new XmlDocument(new MemoryStream(xmldata));

	string data = "reset refs/heads/master\n";
	foreach (child; xml[0]["page"])
		if (child.tag=="revision")
		{
			string summary = child["comment"] ? child["comment"].text : null;
			string committer = child["contributor"]["username"] ? child["contributor"]["username"].text : child["contributor"]["ip"].text;
			fwritefln(stderr, "Revision %s by %s: %s", child["id"].text, committer, summary);
			string text = child["text"].text;
			data ~= 
				"commit refs/heads/master\n" ~ 
				"committer " ~ committer ~ " <" ~ committer ~ "@en.wikipedia.org> " ~ ISO8601toRFC2822(child["timestamp"].text) ~ "\n" ~ 
				"data " ~ .toString(summary.length) ~ "\n" ~ 
				summary ~ "\n" ~ 
				"M 644 inline " ~ name ~ ".txt\n" ~ 
				"data " ~ .toString(text.length) ~ "\n" ~ 
				text ~ "\n" ~ 
				"\n";
		}
	write("fast-import-data", data);

	if (exists(".git"))
		throw new Exception("A git repository already exists here!");
	
	system("git init");
	system("git fast-import --date-format=rfc2822 < fast-import-data");
	std.file.remove("fast-import-data");
	system("git reset --hard");

	return 0;
}

const monthNames = ["Jan", "Feb", "Mar", "Apr", "May", "Jun", "Jul", "Aug", "Sep", "Oct", "Nov", "Dec"];

// 2010-06-15T19:28:44Z
// Feb 6 11:22:18 2007 -0500
string ISO8601toRFC2822(string s)
{
	return monthNames[.toInt(s[5..7])-1] ~ " " ~ s[8..10] ~ " " ~ s[11..13] ~ ":" ~ s[14..16] ~ ":" ~ s[17..19] ~ " " ~ s[0..4] ~ " +0000";
}
