#!/usr/bin/env perl
# Generates pedal-box-schematic.drawio:  perl gen-schematic.pl > pedal-box-schematic.drawio
# Render: drawio --export --format png --scale 1.5 --border 10 --output pedal-box-schematic.png pedal-box-schematic.drawio
# Every wire is a connected edge (source/target cell + pin constraint), so parts can be dragged in draw.io.
use strict; use warnings;
my @cells; my $auto = 10; my %flip;
sub esc { my $s = shift; $s =~ s/&/&amp;/g; $s =~ s/</&lt;/g; $s =~ s/>/&gt;/g; $s =~ s/"/&quot;/g; return $s; }
sub vertex { my ($id, $value, $style, $x, $y, $w, $h, $parent) = @_; $id //= "c" . ($auto++); $parent //= "1";
  $flip{$id} = 1 if $style =~ /flipH=1/;
  push @cells, sprintf('<mxCell id="%s" value="%s" style="%s" vertex="1" parent="%s"><mxGeometry x="%s" y="%s" width="%s" height="%s" as="geometry"/></mxCell>', $id, esc($value), $style, $parent, $x, $y, $w, $h); return $id; }
sub group { my ($id, $x, $y, $w, $h) = @_;
  push @cells, sprintf('<mxCell id="%s" value="" style="group" vertex="1" connectable="0" parent="1"><mxGeometry x="%s" y="%s" width="%s" height="%s" as="geometry"/></mxCell>', $id, $x, $y, $w, $h); return $id; }
# pins are given as VISUAL fractions; draw.io applies flipH/rotation itself, so flipped cells get x mirrored back
sub con { my ($id, $p) = @_; my ($x, $y) = @$p; $x = 1 - $x if $flip{$id}; return ($x, $y); }
my $W = 'edgeStyle=orthogonalEdgeStyle;rounded=0;orthogonalLoop=1;jettySize=auto;html=1;endArrow=none;strokeWidth=1.5;strokeColor=#000000;';
sub edge { my ($extra, $src, $spin, $tgt, $tpin, @pts) = @_;
  my ($sx, $sy) = con($src, $spin); my ($tx, $ty) = con($tgt, $tpin);
  my $style = $W . $extra . sprintf('exitX=%s;exitY=%s;exitDx=0;exitDy=0;exitPerimeter=0;entryX=%s;entryY=%s;entryDx=0;entryDy=0;entryPerimeter=0;', $sx, $sy, $tx, $ty);
  my $mid = @pts ? '<Array as="points">' . join('', map { sprintf('<mxPoint x="%s" y="%s"/>', @$_) } @pts) . '</Array>' : '';
  push @cells, sprintf('<mxCell id="%s" style="%s" edge="1" parent="1" source="%s" target="%s"><mxGeometry relative="1" as="geometry">%s</mxGeometry></mxCell>', "c" . ($auto++), $style, $src, $tgt, $mid); }
sub wire { edge('', @_); }
sub jwire { edge('jumpStyle=arc;jumpSize=8;', @_); }
# straight connector (no orthogonal router): used into the rotated switch, where the router would add a detour
sub swire { my $keep = $W; $W =~ s/edgeStyle=orthogonalEdgeStyle;/edgeStyle=none;/; edge('', @_); $W = $keep; }
sub dot { my ($id, $x, $y, $parent) = @_; vertex($id, '', 'ellipse;fillColor=#000000;strokeColor=#000000;', $x-3, $y-3, 6, 6, $parent); }
sub pad { my ($id, $x, $y, $parent) = @_; vertex($id, '', 'ellipse;fillColor=#ffffff;strokeColor=#000000;strokeWidth=1.5;', $x-4, $y-4, 8, 8, $parent); }
sub text { my ($value, $x, $y, $w, $h, $extra, $parent) = @_;
  vertex(undef, $value, 'text;html=1;strokeColor=none;fillColor=none;whiteSpace=wrap;fontSize=11;' . ($extra // 'align=left;verticalAlign=top;'), $x, $y, $w, $h, $parent); }
# +5V flag: a short bar with the label above; wire into its centre
sub flag5v { my ($id, $x, $y) = @_; vertex($id, '+5V', 'shape=line;strokeWidth=2;strokeColor=#000000;verticalLabelPosition=top;verticalAlign=bottom;fontStyle=1;fontSize=11;html=1;', $x-8, $y-1, 16, 2); }
sub gnd { my ($id, $x, $y) = @_; vertex($id, '', 'shadow=0;dashed=0;strokeWidth=1.5;shape=mxgraph.electrical.signal_sources.signal_ground;', $x-20, $y, 40, 30); }
my $base = 'verticalLabelPosition=bottom;shadow=0;dashed=0;align=center;html=1;verticalAlign=top;strokeWidth=1.5;fontSize=11;';
my $R = $base . 'shape=mxgraph.electrical.resistors.resistor_1;';
my $LED = $base . 'shape=mxgraph.electrical.opto_electronics.led_1;';
my $OPTO = $base . 'shape=mxgraph.electrical.opto_electronics.opto-coupler;flipH=1;';
my $SW = $base . 'shape=mxgraph.electrical.electro-mechanical.make_contact;rotation=90;';
# visual pin positions (fractions of the cell box)
my %P = (
  r_l => [0,0.5], r_r => [1,0.5],
  led_l => [0,0.55], led_r => [1,0.55],
  opto_c => [0.81,0], opto_e => [0.81,1], opto_a => [0.19,0], opto_k => [0.19,1],   # for the flipH opto: transistor visually left
  gnd => [0.5,0], bar => [0.5,0.5], dot => [0.5,0.5], pad_b => [0.5,1], pad_r => [1,0.5],
  jack_t => [0,20/70], jack_s => [0,50/70], jack_t_r => [1,20/70], jack_s_r => [1,50/70],
  sw_1 => [0,1], sw_2 => [1,1],   # make_contact pins, draw.io rotates them
);
# the flipH opto: visually the transistor is LEFT (0.19) and the LED is RIGHT (0.81); con() mirrors these back
$P{opto_c} = [0.19,0]; $P{opto_e} = [0.19,1]; $P{opto_a} = [0.81,0]; $P{opto_k} = [0.81,1];

# measured: key -> [connector pin a (collector), pin b (emitter)]
my @keys = ( [1,2,25],[2,3,25],[3,3,20],[4,3,22],[5,16,26],[6,6,22],[7,7,20],[8,7,25],[9,13,25],[10,13,26],[11,13,22],[12,13,24] );
my @bus = (2,3,6,7,13,16,20,22,24,25,26);
my %bx; for my $i (0..$#bus) { $bx{$bus[$i]} = 130 + 24*$i; }
my $PITCH = 180; my $Y0 = 340;
sub chY { my $n = shift; return $Y0 + $PITCH*$n; }

# title + notes
text('<b>Foot pedal box</b> - 12 opto-isolated pedal inputs (F1-F12), one LED each', 80, 15, 556, 24, 'align=left;verticalAlign=top;fontSize=16;');
text('Salvaged USB keyboard controller (Holtek, USB id 04d9:1702). Pedal down = its LED lights and the opto presses the key.', 80, 42, 540, 20, 'align=left;verticalAlign=top;fontSize=11;');
vertex(undef, '<b>How it works:</b> pedal down closes the loop +5V -> R -> LED -> opto LED -> tip -> switch -> sleeve -> GND. The LED lights and the opto transistor shorts the key\'s two matrix lines exactly like the original key. The matrix only ever sees the transistor (0.2 V drop), so scanning is untouched and the cable is isolated from it.<br><b>Pins:</b> numbers are the keyboard\'s membrane connector pins as measured for F1-F12 (pedals.md). Keys share lines, so only 11 pins are wired: 2, 3, 6, 7, 13, 16 and 20, 22, 24, 25, 26. First number of a pair = collector, second = emitter. If a first-group pin idles low instead of near VCC, swap collector and emitter on all twelve the same way.<br><b>Bonus:</b> a phototransistor conducts one way only, so unlike membrane contacts the pedals cannot ghost each other.<br><b>R1-R12:</b> 220R gives about 8 mA with a red, yellow or green LED. Blue or white LEDs leave no headroom at 5 V.<br><b>PC817 pins:</b> 1 anode, 2 cathode, 3 emitter, 4 collector. PC847 = four per DIP-16, three cover all twelve.',
  'rounded=0;whiteSpace=wrap;html=1;align=left;verticalAlign=top;fontSize=10;spacing=6;fillColor=#f7f7f7;strokeColor=#999999;', 640, 15, 560, 150);

# controller PCB group: rect + labels + 11 connector pads along the bottom edge + VBUS/GND pads on the right edge
my ($PX, $PY) = (80, 180);
group('pcb', $PX, $PY, 440, 80);
vertex('pcb_box', '', 'rounded=0;whiteSpace=wrap;html=1;fillColor=#e9f1e9;strokeColor=#2d6a2d;strokeWidth=1.5;', 0, 0, 440, 80, 'pcb');
text('<b>Salvaged keyboard controller PCB</b> (Holtek 04d9:1702) - membrane connector pins', 4, 3, 432, 16, 'align=center;verticalAlign=middle;fontSize=10;', 'pcb');
text('sense lines (collector)', 38, 25, 144, 12, 'align=center;verticalAlign=middle;fontSize=9;fontStyle=2;', 'pcb');
text('scan lines (emitter)', 182, 25, 120, 12, 'align=center;verticalAlign=middle;fontSize=9;fontStyle=2;', 'pcb');
for my $p (@bus) { text("$p", $bx{$p}-12-$PX, 48, 24, 12, 'align=center;verticalAlign=middle;fontSize=9;fontStyle=1;', 'pcb'); pad("pad_$p", $bx{$p}-$PX, 80, 'pcb'); }
pad('pad_vbus', 440, 35, 'pcb'); text('USB VBUS +5V', 320, 27, 112, 16, 'align=right;verticalAlign=middle;fontSize=10;', 'pcb');
pad('pad_gnd',  440, 65, 'pcb'); text('USB GND',      320, 57, 112, 16, 'align=right;verticalAlign=middle;fontSize=10;', 'pcb');
vertex(undef, 'USB<br>to PC', 'rounded=0;whiteSpace=wrap;html=1;fontSize=10;fillColor=#ffffff;strokeWidth=1.5;', 20, 190, 60, 50);

# junction dots first (bus lines and channel wires both connect to them)
my %lastdot;
for my $k (@keys) { my ($n,$a,$b) = @$k; my $Y = chY($n-1);
  dot("dot_${a}_c$n", $bx{$a}, $Y); dot("dot_${b}_e$n", $bx{$b}, $Y+100);
  $lastdot{$a} = "dot_${a}_c$n"; $lastdot{$b} = "dot_${b}_e$n"; }
for my $p (@bus) { wire("pad_$p", $P{pad_b}, $lastdot{$p}, $P{dot}); }

# power LED chain off the VBUS pad
dot('dot_vbus', 550, 215);
wire('pad_vbus', $P{pad_r}, 'dot_vbus', $P{dot});
flag5v('v5_pwr', 550, 195); wire('dot_vbus', $P{dot}, 'v5_pwr', $P{bar});
vertex('r13', 'R13 1k', $R, 570, 205, 100, 20);     wire('dot_vbus', $P{dot}, 'r13', $P{r_l});
vertex('d13', 'D13 power LED', $LED, 690, 179.25, 100, 65); wire('r13', $P{r_r}, 'd13', $P{led_l});
gnd('gnd_pwr', 810, 245); wire('d13', $P{led_r}, 'gnd_pwr', $P{gnd}, [810,215]);
gnd('gnd_pcb', 550, 245); wire('pad_gnd', $P{pad_r}, 'gnd_pcb', $P{gnd});
text('D13 is on whenever USB 5 V is present (on many desktops also while the PC is off). Any colour, 1k keeps it soft.', 860, 200, 300, 40, 'align=left;verticalAlign=top;fontSize=10;');

# channels
for my $k (@keys) {
  my ($n,$a,$b) = @$k; my $Y = chY($n-1);
  my ($xc, $xl) = (419, 481);
  vertex("u$n", '', $OPTO, 400, $Y+20, 100, 60);
  text("<b>F$n</b>", 432, $Y+3, 36, 14, 'align=center;verticalAlign=middle;fontSize=10;');
  text("U$n PC817", 496, $Y+84, 70, 16, 'align=left;verticalAlign=middle;fontSize=11;');
  jwire("u$n", $P{opto_c}, "dot_${a}_c$n", $P{dot}, [$xc,$Y]);
  jwire("u$n", $P{opto_e}, "dot_${b}_e$n", $P{dot}, [$xc,$Y+100]);
  text("pin $a", 374, $Y-15, 44, 14, 'align=right;verticalAlign=middle;fontSize=9;');
  text("pin $b", 374, $Y+101, 44, 14, 'align=right;verticalAlign=middle;fontSize=9;');
  vertex("d$n", "D$n red LED", $LED . 'flipH=1;', 520, $Y-35.75, 100, 65);
  wire("u$n", $P{opto_a}, "d$n", $P{led_l}, [$xl,$Y]);
  vertex("r$n", "R$n 220R", $R, 640, $Y-10, 100, 20);
  wire("d$n", $P{led_r}, "r$n", $P{r_l});
  flag5v("v5_$n", 780, $Y-20); wire("r$n", $P{r_r}, "v5_$n", $P{bar}, [780,$Y]);
  # jack group: box + lugs
  group("jg$n", 900, $Y+90, 70, 70);
  vertex("j$n", "J$n<br>6.35 mm<br>mono jack", 'rounded=0;whiteSpace=wrap;html=1;fontSize=10;fillColor=#ffffff;strokeWidth=1.5;', 0, 0, 70, 70, "jg$n");
  pad("jt$n", 0, 20, "jg$n"); pad("js$n", 0, 50, "jg$n");
  text('tip', -34, 6, 30, 12, 'align=right;verticalAlign=middle;fontSize=9;', "jg$n");
  text('sleeve', -44, 54, 40, 12, 'align=right;verticalAlign=middle;fontSize=9;', "jg$n");
  wire("u$n", $P{opto_k}, "j$n", $P{jack_t}, [$xl,$Y+110]);
  gnd("gnd$n", 860, $Y+160); wire("j$n", $P{jack_s}, "gnd$n", $P{gnd}, [860,$Y+140]);
  # pedal group: dashed box + switch + labels
  group("pg$n", 1050, $Y+80, 140, 90);
  vertex(undef, '', 'rounded=1;dashed=1;whiteSpace=wrap;html=1;fillColor=none;strokeColor=#555555;', 0, 0, 140, 90, "pg$n");
  vertex("sw$n", '', $SW, 25, 35, 30, 20, "pg$n");
  text("<b>Pedal $n</b>", 50, 4, 86, 14, 'align=center;verticalAlign=middle;fontSize=10;', "pg$n");
  text("SW$n momentary SPST<br>(tattoo pedal)", -10, 92, 160, 28, 'align=center;verticalAlign=top;fontSize=10;', "pg$n");
  text('stock mono cable', 972, $Y+93, 106, 14, 'align=center;verticalAlign=middle;fontSize=9;');
  swire("j$n", $P{jack_t_r}, "sw$n", $P{sw_1});
  swire("j$n", $P{jack_s_r}, "sw$n", $P{sw_2});
}
my $H = chY(11) + 230;
print '<mxfile host="drawio" modified="2026-10-14T00:00:00.000Z" agent="gen-schematic.pl" version="31.1.8" type="device"><diagram name="Pedal box" id="pedal-box"><mxGraphModel dx="0" dy="0" grid="1" gridSize="10" guides="1" tooltips="1" connect="1" arrows="1" fold="1" page="1" pageScale="1" pageWidth="1220" pageHeight="' . $H . '" math="0" shadow="0"><root><mxCell id="0"/><mxCell id="1" parent="0"/>', "\n";
print "$_\n" for @cells;
print '</root></mxGraphModel></diagram></mxfile>', "\n";
