
use Getopt::Advance::Exception:api<2>;
use Getopt::Advance::Utils:api<2>;

unit module Getopt::Advance::NonOption:api<2>;

class NonOptionInfo does Info {
    has $.optname;
    has &.check;
    has $.opt;

    method name() { $!optname; }
    
    method check(Message $msg) {
        &!check($msg.style);
    }

    method process($data) { $data.process($!opt); }                
}

role NonOption does RefOptionSet does Subscriber {
    has Str  $.name;
    has Any  $.value; #| for main is return value, for pos is noa, for cmd is nothing
    has Supplier $.supplier = Supplier.new;
    has $.index;
    has &!callback;

    method set-callback(&!callback) { }

    #| match method
    method match-index(Int $total, Int $index --> Bool) { ... }

    method match-name(Str $name --> Bool) { ... }

    method match-style($style --> Bool) { ... }

    #| others
    method Supply { $!supplier.Supply; }

    method success() { so $!value; }

    method reset-success() { $!value = Any; }

    method reset() { $!value = Any; }

    method has-callback( --> Bool) { &!callback.defined; }

    method CALL-ME(|c) {
        my $ret;
        given &!callback.signature {
            when :($, @) {
                $ret = &!callback(|c);
            }
            when :(@) {
                $ret = &!callback(c.[* - 1]);
            }
			when :() {
				$ret = &!callback();
			}
        }
        return $ret;
    }

    method type( --> Str) { ... }

    method usage( --> Str) { ... }

    #| clone lose the value and sucess
    method clone() {
        nextwith(
            index => %_<index> // $!index.clone,
            name  => %_<name>  // $!name.clone,
            callback => %_<callback> // &!callback.clone,
            supplier    => Supplier.new,
            |%_
        );
    }
}

class NonOption::Main does NonOption {
    submethod TWEAK(:&callback) {
        unless &callback.defined {
            &ga-raise-error('You should provide a &callback to NonOption');
        }
        $!index = -1;
        self.set-callback(&callback);
    }

    method set-callback(
        &callback where .signature ~~ :($, @) | :(@) | :()
    ) {
        self.NonOption::set-callback(&callback);
    }

    method subscribe(Publisher $p) {
        $p.subscribe(
            NonOptionInfo.new(
                optname  => self.usage(),
                check   => sub (\style) {
                    style eq Style::MAIN;
                },
                opt => self,
            )
        );
    }

    method match-index(Int $total, Int $index --> True) { }

    method match-name(Str $name --> True) {}

    method match-style($style --> Bool) { $style == Style::MAIN; }

    method CALL-ME(|c) {
        $!value = self.NonOption::CALL-ME(|c);
        $!supplier.emit([self.owner(), self, c.[* - 1]]);
    }

    method type(--> "main") { }

    method usage() { '*@args' }
}

class NonOption::Cmd does NonOption {
    submethod TWEAK(:&callback) {
        unless &callback.defined {
            &ga-raise-error('You should provide a &callback to NonOption');
        }
        $!index = 0;
        self.set-callback(&callback);
    }

    method set-callback(
        &callback where .signature ~~ :($, @) | :(@) | :()
    ) {
        &!callback = &callback;
    }

    method subscribe(Publisher $p) {
        $p.subscribe(
            NonOptionInfo.new(
                optname  => self.usage(),
                check   => sub (\style) {
                    style eq Style::CMD;
                },
                opt => self,
            )
        );
    }

    method match-index(Int $total, Int $index --> Bool) {
        $index == $!index;
    }

    method match-name(Str $name --> Bool) {
        self.name() eq $name;
    }

    method match-style($style --> Bool) { $style == Style::CMD; }

    method CALL-ME(|c) {
        $!value = so self.NonOption::CALL-ME(|c);
        $!supplier.emit([self.owner(), self, c.[* - 1]]);
    }

    method type( --> "cmd") { }

    method usage() { self.name(); }
}

class NonOption::Pos does NonOption {
    submethod TWEAK(:&callback, :$index) {
        unless &callback.defined {
            &ga-raise-error('You should provide a &callback to NonOption');
        }
        self.set-callback(&callback);
        if $index ~~ Int && $index < 0 {
            &ga-raise-error("Index should be positive number!");
        }
    }

    method set-callback(
        &callback where .signature ~~ :($, $) | :($) | :()
    ) {
        &!callback = &callback;
    }

    method subscribe(Publisher $p) {
        $p.subscribe(
            NonOptionInfo.new(
                optname  => self.usage(),
                check   => sub (\style) {
                    style eq (self.index ~~ WhateverCode ?? Style::WHATEVERPOS !! Style::POS);
                },
                opt => self,
            )
        );
    }

    method match-index(Int $total, $index) {
        my $expect-index = $!index ~~ WhateverCode ??
            $!index.($total) !! $!index;
        my $readl-index = $index ~~ WhateverCode ??
                $index.($total) !! $index;
        return $readl-index == $expect-index;
    }

    method match-name(Str $name --> True ) { }

    method match-style($style --> Bool) { $style == Style::POS; }

    method CALL-ME(|c) {
        my $ret;
        given &!callback.signature {
            when :($, $) {
                $ret = &!callback(|c);
            }
            when :($) {
                $ret = &!callback(c.[* - 1]);
            }
			when :() {
				$ret = &!callback();
			}
        }
        $!supplier.emit([self.owner(), self, c.[* - 1]]);
        return ($!value = $ret);
    }

    method type( --> "pos") { }

    method usage() { self.name(); }
}
