
class X::GA::Exception is Exception {
    has Str $.message;
}

class X::GA::Error is X::GA::Exception { }

class X::GA::ParseFailed is X::GA::Exception { }

class X::GA::OptionInvalid is X::GA::Exception { }

class X::GA::GroupValueInvalid is X::GA::Exception { }

class X::GA::OptionValueInvalid is X::GA::Exception { }

sub raise-error(Str $msg) is export {
    X::GA::Error
    .new(message => $msg)
    .throw;
}

sub try-next() is export {
    X::GA::ParseFailed
    .new(message => "Parsing Failed!")
    .throw;
}

sub invalid-value(Str $msg) is export {
    X::GA::OptionValueInvalid
    .new(message => $msg)
    .throw;
}
