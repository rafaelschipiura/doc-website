#!/usr/bin/env raku
use v6.d;
use JSON::Fast;
use ProcessedPod;

sub ( $pp, %processed, %options ) {
    # This routine creates the JS data structure to be added to the JS query function
    # The data structure is an array of hashes :category, :value, :url
    # Category is used to split up items, value is what is searched for, url is where it is to be found.
    # eg { "category": "Types", "value": "Distribution::Hash", "url": "/type/Distribution::Hash" }
    # The first three items are supplied for some reason.
    my @entries =
        %( :category("Syntax"), :value("# single-line comment"), :url("/language/syntax.html#Single-line_comments") ),
        %( :category("Syntax"), :value("#` multi-line comment"), :url("/language/syntax.html#Multi-line_/_embedded_comments") ),
        %( :category("Signature"), :value(";; (long name)"), :url("/type/Signature.html#index-entry-Long_Names") )
    ;
    my $categories = <Syntax Signature>.SetHash;
    # collect info stored from parsing headers
    my %defns = $pp.get-data('heading')<defs>;
    # structure of %defns is <file name as in processed> => %( <target> => %info )
    # %info = :name, :kind, :subkind, :category
    exit note 'data needed from parsed headings' unless +%defns;
    # structure of processed
    # <filename> => %( :config-data => :kind, @sub-kind, @category )
    # Helper functions as in Documentable
    #| We need to escape names like \. Otherwise, if we convert them to JSON, we
    #| would have "\", and " would be escaped.
    sub escape(Str $s) is export {
        $s.trans([</ \\ ">] => [<\\/ \\\\ \\">]);
    }
    sub escape-json(Str $s) is export {
        $s.subst(｢\｣, ｢%5c｣, :g).subst('"', '\"', :g).subst(｢?｣, ｢%3F｣, :g)
    }
    for %processed.kv -> $fn, $podf {
        @entries.push: %(
            :category( $podf.pod-config-data<kind>.tc ),
            :value( escape( $podf.title )) ,
            :url( escape-json( '/' ~ $fn ~ '.html' ))
        );
        $categories{ $podf.pod-config-data<kind>.tc }++
    }
    for %defns.kv -> $fn, %targets {
        for %targets.kv -> $targ, %info {
            my $category = %info<category>.tc ;
            $category = %info<subkind>.tc ~ ' operator' if $category eq 'Operator';
            $categories{ $category }++;
            @entries.push: %(
                :$category,
                :value( escape( %info<name> ) ),
                :url( escape-json( "/$fn\.html\#$targ" ) )
            )
        }
    }
    $pp.add-data('extendedsearch', $categories.keys);
    'js/search.js'.IO.spurt:
        'var items = '
        ~ to-json( @entries )
        ~ ";\n"
        ~ 'search-temp.js'.IO.slurp;
    [
        [ 'assets/scripts/js/search.js', 'myself', 'js/search.js' ],
        [ 'assets/scripts/js/extended-search.js', 'myself', 'js/extended-search.js' ]
    ]
}