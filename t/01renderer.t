#!/usr/bin/perl

use Test::More;
use Mojo::DOM;
use App::MorePub::Renderer 'render';

my @tests;

push @tests, '<body><i>foo</i></body>', ["foo"];

push @tests, '<body><div><p><i>foo</p></div></body>', ["foo"];

push @tests, '<body><div></div><p><i>foo</p><p>bar</p><div /><p></p></body>',
  [ "foo", "", "bar" ];

push @tests, q{
<body><p>Lorem ipsum dolor sit amet, consectetur adipisici elit, sed eiusmod tempor incidunt ut labore et dolore magna aliqua.</p><p><span></span></p><p>Ut enim ad minim veniam, quis nostrud exercitation ullamco laboris nisi ut aliquid ex ea commodi consequat.</p></body>
},
  [
"Lorem ipsum dolor sit amet, consectetur adipisici elit, sed eiusmod tempor",
    "incidunt ut labore et dolore magna aliqua.",
    "",
"Ut enim ad minim veniam, quis nostrud exercitation ullamco laboris nisi ut",
    "aliquid ex ea commodi consequat.",
  ];

push @tests, q{
<body><p>foo</p><p> </p></body>
}, ["foo"];

push @tests, q{
<body><span> </span><p>foo</p><p> </p><p> </p> <span> </span></body>
}, ["foo"];


push @tests, q{
<body><ul><li>foo</li><li>bar</li><ul></body>
}, [
"  * foo",
"  * bar"
];

push @tests, q{
<body><ul><li>Lorem ipsum dolor sit amet, consectetur adipisici elit, sed eiusmod tempor incidunt ut labore et dolore magna aliqua.</li><li>Ut enim ad minim veniam, quis nostrud exercitation ullamco laboris nisi ut aliquid ex ea commodi consequat.</li></ul></body>}, [
"  * Lorem ipsum dolor sit amet, consectetur adipisici elit, sed eiusmod",
"  tempor incidunt ut labore et dolore magna aliqua.",
"  * Ut enim ad minim veniam, quis nostrud exercitation ullamco laboris nisi",
"  ut aliquid ex ea commodi consequat.",
 ];

push @tests, q
{<body>
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
}, [
"  * foo",
"  *",
"    * bar",
"    * quux",
];


push @tests, q{
<body><pre>if ($foo) {
  die;
}
</pre></body>
}, [
'if ($foo) {',
'  die;',
'}',
];

push @tests, q{
<?xml version="1.0"?>
<body>
  <ul>
    <li>A
		<ul><li>B</li><li>C</li></ol>
  </li>
  </ul>
</body>
}, [
"  * A",
"    * B",
"    * C",
];

push @tests, q{
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
  </ul>
</body>
}, [
'  1. foo',
'  2.',
'    1. bar',
'    2. quux',
'  3. foobar',
];

while ( my ( $input, $expected ) = splice( @tests, 0, 2 ) ) {
    is_deeply( [ render($input) ], $expected );
}

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

