#!/usr/bin/perl

use Test::More;
use App::morepub::Renderer;

sub render {
	App::morepub::Renderer->new->render(shift,'-');
}

is( render('<body><i>foo</i></body>'), "foo" );

is( render('<body><div><p><i>foo</i></p></div></body>'), "foo" );

is(
    render('<body><div></div><p><i>foo</i></p><p>bar</p><div /><p></p></body>'),
    q{foo

bar}
);

is(
    render(
        q{
<body><p>Lorem ipsum dolor sit amet, consectetur adipisici elit, sed eiusmod tempor incidunt ut labore et dolore magna aliqua.</p><p><span></span></p><p>Ut enim ad minim veniam, quis nostrud exercitation ullamco laboris nisi ut aliquid ex ea commodi consequat.</p></body>
}
    ),
    q{Lorem ipsum dolor sit amet, consectetur adipisici elit, sed eiusmod tempor
incidunt ut labore et dolore magna aliqua.

Ut enim ad minim veniam, quis nostrud exercitation ullamco laboris nisi ut
aliquid ex ea commodi consequat.}
);

is(
    render(
        q{
<body><p>foo</p><p> </p></body>
}
    ),
    "foo"
);

is(
    render(
        q{
<body><span> </span><p>foo</p><p> </p><p> </p> <span> </span></body>
}
    ),
    "foo"
);

is(
    render(
        q{
<body><ul><li>foo</li><li>bar</li></ul></body>
}
    ),
    q{  * foo
  * bar}
);

is(
    render(
        q{
<body><ul><li>Lorem ipsum dolor sit amet, consectetur adipisici elit, sed eiusmod tempor incidunt ut labore et dolore magna aliqua.</li><li>Ut enim ad minim veniam, quis nostrud exercitation ullamco laboris nisi ut aliquid ex ea commodi consequat.</li></ul></body>}
    ),
    q{  * Lorem ipsum dolor sit amet, consectetur adipisici elit, sed eiusmod
  tempor incidunt ut labore et dolore magna aliqua.
  * Ut enim ad minim veniam, quis nostrud exercitation ullamco laboris nisi
  ut aliquid ex ea commodi consequat.}
);

is(
    render(
        q{
<body>
  <ul>
    <li>foo</li>
	<li>
      <ul>
        <li>bar</li>
        <li>quux</li>
      </ul>
    </li>
  </ul>
</body>
}
    ),
    q{  * foo
  *
    * bar
    * quux}
);

is(
    render(
        q{
<body><pre>if ($foo) {
  die;
}
</pre></body>
}
    ),
    q{if ($foo) {
  die;
}}
);

is(
    render(
        q{
<?xml version="1.0"?>
<body>
  <ul>
    <li>A
		<ul><li>B</li><li>C</li></ul>
  </li>
  </ul>
</body>
}
    ),
    q{  * A
    * B
    * C}
);

is(
    render(
        q{
<body>
  <ol>
    <li>foo</li>
	<li>
      <ol>
        <li>bar</li>
        <li>quux</li>
      </ol>
    </li>
    <li>foobar</li>
  </ol>
</body>
}
    ),
    q{  1. foo
  2.
    1. bar
    2. quux
  3. foobar}
);

done_testing;

__END__

@@ test13.in
<body><a href="part0002.html#acknowledgments">Acknowledgments</a></body>

@@ test13.out
[1]Acknowledgments

@@ test14.in
<body>
  <p>xxxxx xxxx xxxxxx xxxxx xx xxx xxxxxxxx xxxx xx xxxxx, xxxxxxxxx xx xxxxxxxxx.</p>
  <p>Still</p>
</body>

@@ test14.out
xxxxx xxxx xxxxxx xxxxx xx xxx xxxxxxxx xxxx xx xxxxx, xxxxxxxxx xx xxxxxxxxx.

Still

