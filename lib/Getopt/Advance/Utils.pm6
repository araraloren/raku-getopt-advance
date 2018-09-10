
use Getopt::Advance::Exception:api<2>;

unit module Getopt::Advance::Utils:api<2>;

constant MAXPOSSUPPORT is export = 10240;

class Prefix is export {
    enum < LONG SHORT NULL DEFAULT >;
}

class Style is export {
    enum < XOPT LONG SHORT ZIPARG COMB BSD MAIN CMD POS WHATEVERPOS DEFAULT >;
}

#| register info
role Info { ... }
#| publish message
role Message { ... }
#| publisher
role Publisher { ... }
#| subscriber
role Subscriber { ... }

role ContextProcsser { ... }

role RefOptionSet { ... }

class Debug { ... }

role Info is export {

    method check(Message $msg --> Bool) { ... }

    method process( $data ) { ... }
}

role Message is export {

    method id(--> Int) { ... }

    method data() { ... }
}

role Publisher is export { 
    has Info @.infos;
    
    method publish(Message $msg) {
        for @!infos -> $info {
            if $info.check($msg) {
                $info.process($msg.data);
            }
        }
    }

    method subscribe(Info $info) {
        @!infos.push($info);
    }
}

role Subscriber is export {
    method subscribe(Publisher $p) { ... }
}

role ContextProcesser does Message is export {
    has $.style;
    has @.contexts;
    has $.handler;
    has $.id;

    method id() { $!id; }

    method data() { self; }

    method matched() {
        $!handler.success;
    }

    method process($o) {
        Debug::debug("== message {$!id}: [{self.style}|{self.contexts>>.gist.join(" + ")}]");
        if $!handler.success {
            Debug::debug("- Skip");
        } else {
            Debug::debug("- Match <-> {$o.usage}");
            my $matched = True;
            for @!contexts -> $context {
                if ! $context.success {
                    if $context.match(self, $o) {
                        $context.set(self, $o);
                    } else {
                        $matched = False;
                    }
                }
            }
            if $matched {
                if $o.?need-argument {
                    Debug::debug("  - Call handler to shift argument.");
                    $!handler.skip-next-arg();
                }
                $!handler.set-success();
            }
        }
        Debug::debug("- process end {$!id}");
    }
}

role RefOptionSet is export {
    has $.owner;

    method set-owner($!owner) { }

    method owner() { $!owner; }
}

class Debug is export {
    enum < DEBUG INFO WARN ERROR DIE NOLOG >;

    subset LEVEL of Int where { $_ >= DEBUG.Int && $_ <= ERROR.Int };

    our $g-level = DEBUG;
    our $g-stderr = $*ERR;

    our sub setLevel(LEVEL $level) {
        $g-level = $level;
    }

    our sub setStderr(IO::Handle $handle) {
        $g-stderr = $handle;
    }

    our sub print(Str $log, LEVEL $level = $g-level) {
        if $level >= $g-level {
            $*ERR.print(sprintf "[%-5s]: %s\n", $level, $log);
        }
    }

    our sub debug(Str $log) {
        Debug::print($log, Debug::DEBUG);
    }

    our sub info(Str $log) {
        Debug::print($log, Debug::INFO);
    }

    our sub warn(Str $log) {
        Debug::print($log, Debug::WARN);
    }

    our sub error(Str $log) {
        Debug::print($log, Debug::ERROR);
    }

    our sub die(Str $log) {
        die $log;
    }
}

state @autohv-opt;

sub set-autohv(Str:D $help, Str:D $version) is export {
    @autohv-opt = ($help, $version);
}

sub check-if-need-autohv($optset) is export {
    given @autohv-opt {
        &ga-raise-error("Need the option " ~ .[0] ~ " for autohv")
            if ! $optset.has(.[0]);
        &ga-raise-error("Need the option " ~ .[1] ~ " for autohv")
            if ! $optset.has(.[1]);

        return $optset{.[0]} || $optset{.[1]};
    }
}