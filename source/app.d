#!/usr/bin/env rdmd

import std.algorithm;
import std.array;
import std.conv;
import std.range;
import std.stdio;
import std.string;

immutable help_text = `crunchyroll - watch animes without pain

Usage: crunchyroll -h
       crunchyroll add TITLE
       crunchyroll see TITLE
       crunchyroll remove TITLE
       crunchyroll status [[TITLE] NEW_STATUS]

Options:
    -h, --help  Print this help and exit

Commands:
    add         Add or search for animes by TITLE or URL
    see         See the next episode of TITLE
    remove      Remove an anime by TITLE
    status      See or set the current status of all or one animes

Arguments:
    URL         An crunchyroll anime URL
    TITLE       Part of an anime title.
                Case insensitive, the first title to match is taken.
    NEW_STATUS  Integer, number of the episode in the serie`;

struct AnimeRecord {
    string name;
    string link;

    bool match(string query) {
        return name.toLower.canFind(query.toLower);
    }
}

auto episodeList(AnimeRecord record) {
    import std.net.curl: get;
    string animeUrl = "http://www.crunchyroll.com" ~ record.link;

    return animeUrl
             .get
             .tr("\"", "\n")
             .splitLines
             .filter!(l => l.canFind(record.link ~ "/episode-"))
             .map!(p => "http://www.crunchyroll.com" ~ p.to!string)
             .array
             .retro;
}

auto recordList(string animeList) {
    import asdf: parseJsonByLine, deserialize;

    return animeList.parseJsonByLine
                    .map!(o => o["data"]
                                .byElement
                                .map!(e => e.deserialize!AnimeRecord))
                    .front;
}

auto loadDb(string path) {
    import std.file: exists;
    import asdf: parseJsonByLine, deserialize;

    int[AnimeRecord] result;

    if (!path.exists)
        return result;

    File(path, "r")
        .byLine
        .parseJsonByLine
        .each!(e =>
            e.byElement
             .each!(r => result[r["anime"].deserialize!AnimeRecord] =
                                r["seen"].to!int));

    return result;
}

void saveDb(int[AnimeRecord] db, string path) {
    import asdf: serializeToJson;

    File(path, "w+").write(
        db.byKeyValue
            .array
            .serializeToJson
            .replace("\"key\"",   "\"anime\"")
            .replace("\"value\"", "\"seen\""));
}

bool yesNo(string prompt="", bool defaultValue=false) {
    import core.stdc.stdio: getchar;

    prompt.write;
    write(" [y/n] ");
    switch (getchar()) {
        case 'y':
            return true;
        case 'n':
            return false;
        default:
            return defaultValue;
    }
}

int cmdAdd(int[AnimeRecord] db, string title) {
    import std.net.curl: byLine;

    immutable animeListUrl = "http://www.crunchyroll.com/ajax/"
                           ~ "?req=RpcApiSearch_GetSearchCandidates";

    auto recordSearch = animeListUrl
                            .byLine
                            .dropOne
                            .front
                            .to!string
                            .recordList
                            .filter!(r => r.match(title)
                             || "http://www.crunchyroll.com" ~ r.link == title)
                            .array;

    AnimeRecord record;
    if (recordSearch.length == 1) {
        record = recordSearch[0];
    }
    else {
        writeln("* Found ", recordSearch.length, " matching animes.\n");

        if (recordSearch.length == 0) {
            return 0;
        }

        recordSearch.enumerate.each!((l, r) => writeln(l, "\t", r.name));

        write("* Which one do you want to add?  ");

        uint index;

        try {
            index = stdin.readln.chomp.to!uint;
        }
        catch (ConvException) {
            writeln("* Invalid choice");
            return 1;
        }

        if (index >= recordSearch.length) {
            writeln("* Invalid choice");
            return 1;
        }

        record = recordSearch[index];
    }

    if (record in db) {
        writeln("* ", record.name, " is already in your list");
    }
    else {
        writeln("* Adding: ", record.name);
        db[record] = 0;
    }

    return 0;
}

void cmdRemove(int[AnimeRecord] db, string title) {
    auto toRemove = db.keys
                      .filter!(r => r.match(title))
                      .array;

    if (toRemove.length == 0) {
        writeln("* Nothing to remove");
    }
    else if (toRemove.length > 1) {
        writeln("* Too many files match this title");
    }
    else {
        assert(toRemove.length == 1);
        writeln("* Removing: ", toRemove[0].name);
        db.remove(toRemove[0]);
    }
}

void cmdStatus(int[AnimeRecord] db, string title="", int newStatus=-1) {
    if (newStatus < 0) {
        db.byKeyValue
          .filter!(kv => kv.key.match(title))
          .each!(kv => writefln("%0.2d\t%s", kv.value, kv.key.name));
    }
    else {
        db.keys
          .filter!(r => r.match(title))
          .each!(r => db[r] = newStatus);
    }
}

int cmdSee(int[AnimeRecord] db, string title) {
    import std.process: execute;

    auto record = db.keys
                    .filter!(r => r.match(title))
                    .front;

    if (record !in db) {
        db[record] = 0;
    }

    auto toSee = record.episodeList
                       .drop(db[record])
                       .takeOne;

    if (toSee.length == 0) {
        writeln("* No episode found");
        return 1;
    }

    writeln("* Playing episode ", db[record] + 1,
            " from ", record.name,
            ": " ~ toSee.front);

    immutable play = execute(["see", "-f", toSee.front]);

    if (play.status == 0) {
        db[record]++;
    }

    return 0;
}

int main(string[] args) {
    if (args.canFind("-h")) {
        writeln(help_text);
        return 0;
    }

    immutable savePath = "/home/cym13/.local/share/crunchyroll/db.json";
    auto db = loadDb(savePath);
    scope(success) saveDb(db, savePath);

    if (args.length < 2 || args[1] == "status") {
        switch (args.length) {
            case 1:
            case 2:  cmdStatus(db);
                     break;
            case 3:  cmdStatus(db, args[2]);
                     break;
            default: cmdStatus(db, args[2], args[3].to!int);
                     break;
        }
        return 0;
    }

    if (args.length < 3) {
        writeln(help_text);
        return 1;
    }
    else if (args[1] == "remove") {
        cmdRemove(db, args[2]);
        return 0;
    }
    else if (args[1] == "see") {
        auto result = cmdSee(db, args[2]);
        if (result == 1 && yesNo("Remove this anime?"))
            cmdRemove(db, args[2]);
        return result;
    }
    else if (args[1] == "add") {
        return cmdAdd(db, args[2]);
    }
    else {
        writeln(help_text);
        return 1;
    }
}
