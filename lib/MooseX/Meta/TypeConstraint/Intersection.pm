package MooseX::Meta::TypeConstraint::Intersection;

use Moose;
use MooseX::Types::Moose qw/ArrayRef Str/;
use Moose::Util::TypeConstraints 'find_type_constraint';
use namespace::autoclean;

extends 'Moose::Meta::TypeConstraint';

has type_constraints => (
    is      => 'ro',
    isa     => ArrayRef,
    default => sub { [] },
);

has name => (
    is      => 'ro',
    isa     => Str,
    lazy    => 1,
    builder => '_build_name',
);

around new => sub {
    my ($next, $class, %args) = @_;
    my $name = join '&' => sort { $a cmp $b }
        map { $_->name } @{ $args{type_constraints} };
    return $class->$next(name => $name, %args);
};

sub _actually_compile_type_constraint {
    my ($self) = @_;
    my @type_constraints = @{ $self->type_constraints };
    return sub {
        my ($value) = @_;

        for my $type (@type_constraints) {
            return unless $type->check($value);
        }

        return 1;
    };
}

# this is stolen from TC::Union. meh
sub equals {
    my ($self, $type_or_name) = @_;
    my $other = find_type_constraint($type_or_name);

    return unless $other->isa(__PACKAGE__);

    my @self_constraints  = @{ $self->type_constraints  };
    my @other_constraints = @{ $other->type_constraints };

    return unless @self_constraints == @other_constraints;

  CONSTRAINT: for my $constraint (@self_constraints) {
        for (my $i = 0; $i < @other_constraints; $i++) {
            if ($constraint->equals($other_constraints[$i])) {
                splice @other_constraints, $i, 1;
                next CONSTRAINT;
            }
        }
    }

    return @other_constraints == 0;
}

# this too, although i'm not too sure what the point of it is
sub parents {
    my ($self) = @_;
    return $self->type_constraints;
}

sub validate {
    my ($self, $value) = @_;
    my $msg = '';

    for my $tc (@{ $self->type_constraints }) {
        my $err = $tc->validate($value);
        next unless defined $err;
        $msg .= (length $msg ? ' and ' : '') . $err;
    }

    return length $msg
        ? $msg . ' in ' . $self->name
        : undef;
}

sub is_subtype_of {
    confess 'Not yet implemented';
}

sub create_child_type {
    confess 'Not yet implemented';
}

1;
