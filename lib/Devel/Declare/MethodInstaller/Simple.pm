package Devel::Declare::MethodInstaller::Simple;

use base 'Devel::Declare::Context::Simple';

use Devel::Declare ();
use Sub::Name;
use strict;
use warnings;

sub install_methodhandler {
  my $class = shift;
  my %args  = @_;
  {
    no strict 'refs';
    *{$args{into}.'::'.$args{name}}   = sub (&) {};
  }

  my $ctx = $class->new(%args);
  Devel::Declare->setup_for(
    $args{into},
    { $args{name} => { const => sub { $ctx->parser(@_) } } }
  );
}

sub strip_attrs {
  my $self = shift;
  $self->skipspace;

  my $Offset  = $self->offset;
  my $linestr = Devel::Declare::get_linestr;
  my $attrs   = '';

  if (substr($linestr, $Offset, 1) eq ':') {
    while (substr($linestr, $Offset, 1) ne '{') {
      if (substr($linestr, $Offset, 1) eq ':') {
        substr($linestr, $Offset, 1) = '';
        Devel::Declare::set_linestr($linestr);

        $attrs .= ':';
      }

      $self->skipspace;
      $Offset  = $self->offset;
      $linestr = Devel::Declare::get_linestr();

      if (my $len = Devel::Declare::toke_scan_word($Offset, 0)) {
        my $name = substr($linestr, $Offset, $len);
        substr($linestr, $Offset, $len) = '';
        Devel::Declare::set_linestr($linestr);

        $attrs .= " ${name}";

        if (substr($linestr, $Offset, 1) eq '(') {
          my $length = Devel::Declare::toke_scan_str($Offset);
          my $arg    = Devel::Declare::get_lex_stuff();
          Devel::Declare::clear_lex_stuff();
          $linestr = Devel::Declare::get_linestr();
          substr($linestr, $Offset, $length) = '';
          Devel::Declare::set_linestr($linestr);

          $attrs .= "(${arg})";
        }
      }
    }

    $linestr = Devel::Declare::get_linestr();
  }

  return $attrs;
}

sub parser {
  my $self = shift;
  $self->init(@_);

  $self->skip_declarator;
  my $name   = $self->strip_name;
  my $proto  = $self->strip_proto;
  my $attrs  = $self->strip_attrs;
  my @decl   = $self->parse_proto($proto);
  my $inject = $self->inject_parsed_proto(@decl);
  if (defined $name) {
    $inject = $self->scope_injector_call() . $inject;
  }
  $self->inject_if_block($inject, $attrs ? "sub ${attrs} " : '');
  if (defined $name) {
    my $pkg = $self->get_curstash_name;
    $name = join( '::', $pkg, $name )
      unless( $name =~ /::/ );
    $self->shadow( sub (&) {
      my $code = shift;
      # So caller() gets the subroutine name
      no strict 'refs';
      *{$name} = subname $name => $code;
    });
  } else {
    $self->shadow(sub (&) { shift });
  }
}

sub parse_proto { }

sub inject_parsed_proto {
  return $_[1];
}

1;

