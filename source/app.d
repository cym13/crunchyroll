#!/usr/bin/env rdmd

import std.algorithm;
import std.array;
import std.conv;
import std.range;
import std.stdio;
import std.string;

struct AnimeRecord {
    string name;
    string link;
}

auto search(RecordRange)(RecordRange records, string query) {
    return records
             .filter!(r => r.name
                            .toLower
                            .canFind(query.toLower));
}

auto episodeList(AnimeRecord record) {
    import std.net.curl;
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
    import asdf;

    return animeList.parseJsonByLine
                    .map!(o => o["data"]
                                .byElement
                                .map!(e => e.deserialize!AnimeRecord))
                    .front;
}

auto loadSeen(string path) {
    import std.file;
    import asdf;

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

void saveSeen(int[AnimeRecord] seen, string path) {
    import asdf;

    File(path, "w+").write(
        seen.byKeyValue
            .array
            .serializeToJson
            .replace("\"key\"",   "\"anime\"")
            .replace("\"value\"", "\"seen\""));
}

int main(string[] args) {
    import std.process;
    import std.net.curl;

    if (args.length == 1) {
        writeln("Usage: crunchyroll NAME");
        return 1;
    }

    immutable savePath = "/home/cym13/.local/share/crunchyroll/seen.json";

    immutable animeListUrl = "http://www.crunchyroll.com/ajax/"
                           ~ "?req=RpcApiSearch_GetSearchCandidates";

    auto animeList = animeListUrl.byLine.dropOne.front.to!string;

    auto seen = loadSeen(savePath);
    scope(success) saveSeen(seen, savePath);

    auto recordSearch = animeList.recordList.search(args[1]).array;

    AnimeRecord record;
    if (recordSearch.length == 1) {
        record = recordSearch[0];
    }
    else {
        writeln("* Recently seen:");

        seen.byKey
            .array
            .retro
            .take(5)
            .each!(a => writeln("\t", a.name, " (", seen[a], ")"));

        writeln("\n* Found ", recordSearch.length, " matching animes.\n");

        recordSearch.enumerate.each!((l, r) => writeln(l, "\t", r.name));

        write("\n* Which one do you want to see?  ");

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

    if (record !in seen) {
        seen[record] = 0;
    }

    writeln("* Playing episode ", seen[record] + 1,
            " from ", record.name,
            " : http://www.crunchyroll.com" ~ record.link);

    auto toSee = record.episodeList
                       .drop(seen[record])
                       .takeOne;

    if (toSee.length == 0) {
        writeln("* No episode found");
        return 1;
    }

    auto play = execute(["see", "-f", toSee.front]);

    if (play.status == 0) {
        seen[record]++;
    }

    return 0;
}
