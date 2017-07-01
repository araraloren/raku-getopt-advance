
class X::GA::Exception is Exception {
    has Str $.message;
}

class X::GA::ParseFailed is X::GA::Exception { }

sub ga-try-next(Str $msg) is export {
    X::GA::ParseFailed
    .new(message => $msg)
    .throw;
}

class X::GA::OptionInvalid is X::GA::Exception { }

sub ga-invalid-value(Str $msg) is export {
    X::GA::OptionInvalid
    .new(message => $msg)
    .throw;
}

class X::GA::OptionTypeInvalid is X::GA::Exception { }


class X::GA::Error is X::GA::Exception { }

sub ga-raise-error(Str $msg) is export {
    X::GA::Error
    .new(message => $msg)
    .throw;
}

class X::GA::NonOptionCallFailed is X::GA::Exception { }

sub ga-may-usage(Str $msg) is export {
    X::GA::NonOptionCallFailed
    .new(message => $msg)
    .throw;
}

class X::GA::GroupValueInvalid is X::GA::Exception { }

sub ga-group-error(Str $msg) is export {
    X::GA::GroupValueInvalid
    .new(message => $msg)
    .throw;
}

#`(
class X::GA::OptionTypeInvalid is X::GA::Exception { }

class X::GA::OptionInvalid is X::GA::Exception { }



class X::GA::OptionValueInvalid is X::GA::Exception { }

sub ga-raise-error(Str $msg) is export {
    X::GA::Error
    .new(message => $msg)
    .throw;
}



sub ga-invalid-value(Str $msg) is export {
    X::GA::OptionInvalid
    .new(message => $msg)
    .throw;
}
)
