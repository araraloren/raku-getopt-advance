
use Getopt::Advance::Option;
use Getopt::Advance::Exception;

my grammar Grammar::Option {
	rule TOP {
		^ <option> $
	}

	token option {
		[
			<short>? '|' <long>? '=' <type>
			|
			<name> '=' <type>
		]
        [ <optional> | <deactivate> ]?
        [ <optional> | <deactivate> ]?
	}

	token short {
		<name>
	}

	token long {
		<name>
	}

	token name {
		<-[\|\=]>+
	}

	token type {
		\w+
	}

	token optional {
		'!'
	}

	token deactivate {
		'/'
	}
}

my class Actions::Option {
	has $.deactivate;
	has $.optional;
	has $.type;
	has $.long;
	has $.short;

	method option($/) {
		without ($<long> | $<short> ) {
			my $name = $<name>.Str;

			$name.chars > 1 ?? ($!long = $name) !! ($!short = $name);
		}
	}

	method short($/) {
		$!short = $/.Str;
	}

	method long($/) {
		$!long = $/.Str;
	}

	method type($/) {
		$!type = $/.Str;
	}

	method optional($/) {
		$!optional = True;
	}

	method deactivate($/) {
		$!deactivate = True;
	}
}

class Types::Manager {
    has %.types handles <AT-KEY keys values kv pairs>;

    method has(Str $name --> Bool) {
        %!types{$name}:exists;
    }

    method innername(Str:D $name) {
        %!types{$name}.type;
    }

    method register(Str:D $name, Mu:U $type --> ::?CLASS:D) {
        if not self.in($name) {
            %!types{$name} = $type;
        }
        self;
    }

    sub opt-string-parse(Str $str) {
        my $action = Actions::Option.new;
        unless Grammar::Option.parse($str, :actions($action)) {
            &raise-error("{$str}: Unable to parse option string!");
        }
        return $action;
    }

    #`( Option::Base
        has @.name;
        has &.callback;
        has $.optional;
        has $.annotation;
        has $.value;
        has $.default-value;
    )
    multi method create(Str $str, :$value, :&callback) {
        my $setting = &opt-string-parse($str);
        my $option;

        unless %!types{$setting.type} ~~ Option {
            &raise-error("{$setting.type}: Invalid option type!");
        }
        $option = %!types{$setting.type}.new(
            name        => [$setting.short // "", $setting.long // ""],
            callback    => &callback,
            optional    => $setting.optional,
            value       => $value,
            deactivate  => $setting.deactivate,
        );
        $option;
    }

    multi method create(Str $str,  Str:D $annotation, :$value, :&callback) {
        my $setting = &opt-string-parse($str);
        my $option;

        unless %!types{$setting.type} ~~ Option {
            &raise-error("{$setting.type}: Invalid option type!");
        }
        $option = %!types{$setting.type}.new(
            name        => [$setting.short // "", $setting.long // ""],
            callback    => &callback,
            optional    => $setting.optional,
            value       => $value,
            annotation  => $annotation,
            deactivate  => $setting.deactivate,
        );
        $option;
    }
}
