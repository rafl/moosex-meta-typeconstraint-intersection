package MooseX::Meta::TypeConstraint::Intersection;
# ABSTRACT: An intersection of Moose type constraints

use Moose;
use MooseX::Types::Moose qw/ArrayRef/;
use Moose::Util::TypeConstraints 'find_type_constraint';
use aliased 'Moose::Meta::TypeConstraint';
use namespace::autoclean -also => 'TypeConstraint';

=head1 DESCRIPTION

This class represents an intersection of type constraints. An intersection
takes multiple type constraints, and is true if all of its member constraints
are true.

=head1 INHERITANCE

C<MooseX::Meta::TypeConstraint::Intersection> is a subclass of
L<Moose::Meta::TypeConstraint>.

=cut

extends TypeConstraint;

=attr type_constraints

The member type constraints of this intersection.

=cut

has type_constraints => (
    is      => 'ro',
    isa     => ArrayRef[TypeConstraint],
    default => sub { [] },
);

=method new(%options)

This creates a new intersection type constraint based on the given C<%options>.

It takes the same options as its parent. It also requires an additional option,
C<type_constraints>. This is an array reference containing the
L<Moose::Meta::TypeConstraint> objects that are the members of the intersection
type. The C<name> option defaults to the names of all of these member types
sorted and then joined by an ampersand (&).

=cut

around new => sub {
    my ($next, $class, %args) = @_;
    my $name = join '&' => sort { $a cmp $b }
        map { $_->name } @{ $args{type_constraints} };
    return $class->$next(name => $name, %args);
};

=method check($value)

Checks a C<$value> against the intersection constraint. If all member
constraints accept the value, the value is valid and something true is
returned.

=cut

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

=method equals($other_constraint)

A type is considered equal if it is also an intersection type, and the two
intersections have the same member types.

=cut

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

=method parents

This returns the same constraint as the C<type_constraints> method.

=cut

# this too, although i'm not too sure what the point of it is
sub parents {
    my ($self) = @_;
    return $self->type_constraints;
}

=method validate($value)

Like C<check>, but returns an error message including all of the error messages
returned by the member constraints, or C<undef>.

=cut

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

=method is_subtype_of($other_constraint)

This returns true if the C<$other_constraint> is also an intersection
constraint and contains at least all of the member constraints of the
intersection this method is called on.

=cut

sub is_subtype_of {
    my ($self, $type_or_name) = @_;
    my $other = find_type_constraint($type_or_name);

    return unless $other->isa(__PACKAGE__);

    my @self_constraints  = @{ $self->type_constraints  };
    my @other_constraints = @{ $other->type_constraints };

    return if @self_constraints < @other_constraints;

  CONSTRAINT: for my $tc (@other_constraints) {
        for (my $i = 0; $i < @self_constraints; $i++) {
            if ($tc->is_subtype_of($self_constraints[$i])) {
                splice @self_constraints, $i, 1;
                next CONSTRAINT;
            }
        }
    }

    return @self_constraints == 0;
}

1;
