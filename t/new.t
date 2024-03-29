use strict;
use warnings;
use Devel::Declare ();
use Test::More;

{
  package FoomHandlers;

  use strict;
  use warnings;

  our ($Declarator, $Offset);

  sub skip_declarator {
    $Offset += Devel::Declare::toke_move_past_token($Offset);
  }

  sub skipspace {
    $Offset += Devel::Declare::toke_skipspace($Offset);
  }

  sub strip_name {
    skipspace;
    if (my $len = Devel::Declare::toke_scan_word($Offset, 1)) {
      my $linestr = Devel::Declare::get_linestr();
      my $name = substr($linestr, $Offset, $len);
      substr($linestr, $Offset, $len) = '';
      Devel::Declare::set_linestr($linestr);
      return $name;
    }
    return;
  }

  sub strip_proto {
    skipspace;
    
    my $linestr = Devel::Declare::get_linestr();
    if (substr($linestr, $Offset, 1) eq '(') {
      my $length = Devel::Declare::toke_scan_str($Offset);
      my $proto = Devel::Declare::get_lex_stuff();
      Devel::Declare::clear_lex_stuff();
      $linestr = Devel::Declare::get_linestr();
      substr($linestr, $Offset, $length) = '';
      Devel::Declare::set_linestr($linestr);
      return $proto;
    }
    return;
  }

  sub shadow {
    my $pack = Devel::Declare::get_curstash_name;
    Devel::Declare::shadow_sub("${pack}::${Declarator}", $_[0]);
  }

  sub inject_str {
    my $linestr = Devel::Declare::get_linestr;
    substr($linestr, $Offset, 0) = $_[0];
    Devel::Declare::set_linestr($linestr);
  }

  sub strip_str {
    my $linestr = Devel::Declare::get_linestr;
    if (substr($linestr, $Offset, length($_[0])) eq $_[0]) {
      substr($linestr, $Offset, length($_[0])) = '';
      Devel::Declare::set_linestr($linestr);
      return 1;
    }
    return 0;
  }

  sub const {
    local ($Declarator, $Offset) = @_;
    skip_declarator;
    my $name = strip_name;
    my $str = "happy ".(defined $name ? "foom: ${name}" : "anonymous foom");
    if (defined(my $proto = strip_proto)) {
      $str .= "; ${proto}";
    }
    shadow(sub { $str });
  }

  package Foo;

  use strict;
  use warnings;

  sub foom { }

  BEGIN {
    Devel::Declare->setup_for(
      __PACKAGE__,
      { foom => {
          const => \&FoomHandlers::const,
      } }
    );
  }

  ::is(foom, "happy anonymous foom", "foom");

  ::is(foom KABOOM, "happy foom: KABOOM", "foom KABOOM");

  ::is(foom (zoom), "happy anonymous foom; zoom", "foom (zoom)");

  ::is(foom KABOOM (zoom), "happy foom: KABOOM; zoom", "foom KABOOM (zoom)");
}

done_testing;
