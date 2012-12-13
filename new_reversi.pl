#!/usr/bin/perl -w
#(c)Shulga

use v5.14.2;
use Tk;
use strict;
use Encode;
use IO::Socket;
use IO::Select;

my $mw = MainWindow->new;
my $canvas = $mw->Canvas(qw/-width 480 -height 480/,-background => "#6A5ACD")->grid;
my $white=$mw->Photo(-file =>"white.gif");
my $black=$mw->Photo(-file =>"black.gif");
my ($quantityChipsOnTable,$quantityWhite,$quantityBlack) = (4,2,2);
my %coordinates=();
my %validMoves=();
my %validSides=();
my %quantityEatenChips=();
my %moveWeight=();
my $currentColour = "black";
my %cells=();
my @sides=();
my ($ai,$socket,$send,$net)=(0,0,0,0);

sub createBoard($$){
	my($main,$canv) = @_;
	$main->title("Reversi"); 
	$main->geometry("640x480");
	$canv->configure("-scrollregion" => [0,0, 480, 480]);
	$canv->createGrid(0, 0, 60, 60, -width => 3, -lines => 1); 
	$canv->createLine(479,0, 479,480,-fill => "black", -width => 3); 
	$canv->createLine(0,480, 480,480,-fill => "black", -width => 5); 
	$canv->createImage(210,210,-image => $white,-tags => "image210210");
	$canv->createImage(270,270,-image => $white,-tags => "image270270");
	$canv->createImage(270,210,-image => $black,-tags => "image270210");
	$canv->createImage(210,270,-image => $black,-tags => "image210270");
	$cells{210210}="white";
	$cells{270270}="white";
	$cells{270210}="black";
	$cells{210270}="black";
}

sub createMenu($){
	my $main = shift;
	$main->configure(-menu => my $menubar = $main->Menu);
  my $file = $menubar->cascade(-label=>'~File',-tearoff=>0);
  my $help = $menubar->cascade(-label=>'~Help',-tearoff=>0);
  my $netgame=$file->cascade(-label=>'~Net game',-tearoff=>0);
  my $newgame=$file->cascade(-label=>'~New game',-tearoff=>0);
	$newgame->command(-label=>'Hotseat',-underline=>0,-command=>sub{
		$ai = 0;
		&newGame(0);
		});
	$newgame->separator;
	my $a_i=$newgame->cascade(-label=>'~PvE',-tearoff=>0);
	$a_i->command(-label=>"Easy",-underline=>0,-command=>sub{
		$ai=1;
		$main->messageBox(-message=>"Complexity Level - Easy", -type => "ok");
		&newGame(1);});
	$a_i->command(-label=>"Medium",-underline=>0,-command=>sub{
		$ai=2;
		$main->messageBox(-message=>"Complexity Level - Medium", -type => "ok");
		&newGame(2);});
	$a_i->command(-label=>"Hard",-underline=>0,-command=>sub{
		$ai=3;
		$main->messageBox(-message=>"Complexity Level - Hard", -type => "ok");
		&newGame(3);});
	$newgame->separator;
	$newgame->command(-label=>'PvP',-underline=>0,-command=>\&newNetGame);
	$netgame->command(-label=>'Connect', -underline=>0,-command=> \&netGameConnect);
  $netgame->separator;
  $netgame->command(-label=>'Start Server', -underline=>0,-command=> \&netGameServer);

	$file->separator;
	$file->command(-label=>"Score",-accelerator=>'Ctrl-s',-underline=>0,-command=>sub{
			my $tl=$main->Toplevel(-title =>'Score');
			$tl->geometry("300x150");
      $tl->Label(-text => "White: $quantityWhite \nBlack: $quantityBlack")->pack;
		});
	$file->separator;
	$file->command(-label=>"Quit",-accelerator=>'Ctrl-q',-underline=>0,-command=>sub{exit});
	
	$help->command(-label=>"About",-accelerator=>'Ctrl-p',-underline=> 0,-command=>sub {
            my $tl=$main->Toplevel(-title =>'About');
            $tl->Label(-text => "Name: Reversi\nType: Game\nGenre: Logical\nAuthor: Max Shulga\nCountry: Russia\nVersion: 1.0.1 \nProgramming language: Perl\nVersion Perl: 5.14.2\nEmail: mshulgaa\@gmail.com")->pack;
        });
  $help->separator;
  $help->command(-label => "Rules",-accelerator=>'Ctrl-i',-underline=>0,-command=>sub{
    	my $tl=$mw->Toplevel(-title =>'Rules');
    	open(FILE,'rules.txt');
	    my @a;
    	while(<FILE>){
    		push @a,decode 'utf8',$_;
    	}
	    $tl->Label(-text => "@a")->pack;});
}

sub move{
	my ($canv, $x, $y) = @_;
	my $borderLine = 420; 
	$x = &findMiddleCoordinate($canv,$x,$borderLine);
	$y = &findMiddleCoordinate($canv,$y,$borderLine);
	&validMove($currentColour);	
	if(exists $validMoves{$x.$y}){
		if($currentColour eq "black"){
			$quantityBlack++;
			$canv->createImage($x,$y,-image => $black,-tags => "image".$x.$y);
			$cells{$x.$y} = "black";
			&eatEnemyChips($x,$y);
			$currentColour = "white";
		}else{
			$quantityWhite++;
			$canv->createImage($x,$y,-image => $white,-tags => "image".$x.$y);
			$cells{$x.$y} = "white";
			&eatEnemyChips($x,$y);
			$currentColour = "black";
		}
		$quantityChipsOnTable++;			
	}
	&result if($quantityChipsOnTable==64);
	if(($ai==1) && ($currentColour eq "white")){
		&easyAI;
	}
	if(($ai==2) && ($currentColour eq "white")){
		&mediumAI;
	}
	if(($ai==3) && ($currentColour eq "white")){
		&hardAI;
	}
	&result if($quantityChipsOnTable==64);
	&validMove($currentColour);
	my @a = keys %validMoves;
	if(not exists $a[0]){
		if($currentColour eq "white"){
			$currentColour = "black";
			&validMove($currentColour);
			my @b = keys %validMoves;
			&result if(not exists $b[0]);
			$mw->messageBox(-message=>"White player hasn't course", -type => "ok");
		}else{
			$currentColour = "white";	
			&validMove($currentColour);
			my @b = keys %validMoves;
			&result if(not exists $b[0]);
			$mw->messageBox(-message=>"Black player hasn't course", -type => "ok");
		}
	}
	if($net){
		&netGame($x,$y);
	}
}

sub findMiddleCoordinate($$$) {
	my ($canv, $coord,$borderLine) = @_;
	$coord = $canv->canvasx($coord);
	while($coord < $borderLine){
		$borderLine-=60;
	}
	$borderLine+=30;
	return $borderLine;
}

sub validMove($) {
	my $colour = shift;
	my $enemyColour;
	%validMoves=();
	%validSides=();
	%quantityEatenChips=();
	%moveWeight=();
	@sides=();
	if($colour eq "black"){
		$enemyColour = "white";
	}elsif($colour eq "white"){
		$enemyColour = "black";
	}
	for(my $y = 30;$y <= 450;$y+=60){
		for(my $x = 30;$x <= 450;$x+=60){
			if(not exists $cells{$x.$y}){
				&findValidSide($x,$y,$colour,$enemyColour);
			}
		}
	}	
}

sub findValidSide($$$$) {
	
	my ($x,$y,$colour,$enemyColour) = @_;
	if(exists $cells{($x-60).$y}){
		&fillValidMovesSet($x,-60,$y,0,$colour,$enemyColour);
	}
	if(exists $cells{($x+60).$y}){
		&fillValidMovesSet($x,60,$y,0,$colour,$enemyColour);
	}
	if(exists $cells{$x.($y-60)}){
		&fillValidMovesSet($x,0,$y,-60,$colour,$enemyColour);
	}
	if(exists $cells{$x.($y+60)}){
		&fillValidMovesSet($x,0,$y,60,$colour,$enemyColour);
	}
	if(exists $cells{($x-60).($y-60)}){
		&fillValidMovesSet($x,-60,$y,-60,$colour,$enemyColour);
	}
	if(exists $cells{($x+60).($y-60)}){
		&fillValidMovesSet($x,60,$y,-60,$colour,$enemyColour);
	}
	if(exists $cells{($x-60).($y+60)}){
		&fillValidMovesSet($x,-60,$y,60,$colour,$enemyColour);
	}
	if(exists $cells{($x+60).($y+60)}){
		&fillValidMovesSet($x,60,$y,60,$colour,$enemyColour);
	}
	@sides=();
}

=cut
###Сторонам соответствуют числа###
##################################
########	1-left      ##########
########	2-right     ##########
########	3-top       ##########
########	4-bot       ##########
########	5-leftTop   ##########
########	6-rightTop  ##########
########	7-leftBot   ##########
########	8-rightBot  ##########
##################################	
=cut

sub fillValidMovesSet($$$$$$) {
	my ($x,$diffX,$y,$diffY,$colour,$enemyColour) = @_;
	my ($tmpX,$tmpY) = ($x+$diffX,$y+$diffY);
	my $count = 0;
	if($cells{$tmpX.$tmpY} eq $enemyColour){
		while(exists $cells{$tmpX.$tmpY}){
			if($cells{$tmpX.$tmpY} eq $enemyColour){
				$quantityEatenChips{$x.$y}++;
				$moveWeight{$x.$y}++;
				$count++;
				$tmpX+=$diffX;
				$tmpY+=$diffY;
			}
			else{last}
		}
		if(exists $cells{$tmpX.$tmpY}){
			if($cells{$tmpX.$tmpY} eq $colour){
				$validMoves{$x.$y}++;
				if(&isAngularCell($x.$y)){
					$moveWeight{$x.$y}+=10;
				}
				elsif(&isGoodEdgeCell($x.$y)){
					$moveWeight{$x.$y}+=5;
				}
				if(($diffX==(-60)) && ($diffY==0)) {
					push @sides , 1;
				}
				elsif(($diffX==60) && ($diffY==0)){
					push @sides , 2;
				}
				elsif(($diffX==0) && ($diffY==(-60))){
					push @sides , 3;
				}
				elsif(($diffX==0) && ($diffY==60)){
					push @sides , 4;
				}
				elsif(($diffX==(-60)) && ($diffY==(-60))){
					push @sides , 5;
				}
				elsif(($diffX==60) && ($diffY==(-60))){
					push @sides , 6;
				}
				elsif(($diffX==(-60)) && ($diffY==60)){
					push @sides , 7;
				}
				elsif(($diffX==60) && ($diffY==60)){
					push @sides , 8;
				}
			}else{$quantityEatenChips{$x.$y}-=$count;$moveWeight{$x.$y}-=$count;}
		}else{$quantityEatenChips{$x.$y}-=$count;$moveWeight{$x.$y}-=$count;}
	}
	$validSides{$x.$y} = [ @sides ];
}

sub eatEnemyChips($$) {
	my ($x,$y) = @_;
	my $enemyColour;
	if($currentColour eq "black"){
		$enemyColour = "white";
	}elsif($currentColour eq "white"){
		$enemyColour = "black";
	}
	for my $side (@{$validSides{$x.$y}}){
		if($side == 1){
			&reverseChips($x,(-60),$y,0,$currentColour,$enemyColour);
		}
		elsif($side == 2){
			&reverseChips($x,60,$y,0,$currentColour,$enemyColour);
		}
		elsif($side == 3){
			&reverseChips($x,0,$y,(-60),$currentColour,$enemyColour);
		}
		elsif($side == 4){
			&reverseChips($x,0,$y,60,$currentColour,$enemyColour);
		}
		elsif($side == 5){
			&reverseChips($x,(-60),$y,(-60),$currentColour,$enemyColour);
		}
		elsif($side == 6){
			&reverseChips($x,60,$y,(-60),$currentColour,$enemyColour);	
		}
		elsif($side == 7){
			&reverseChips($x,(-60),$y,60,$currentColour,$enemyColour);
		}
		elsif($side == 8){
			&reverseChips($x,60,$y,60,$currentColour,$enemyColour);
		}
	}
}

sub reverseChips($$$$$$) {
	my ($x,$diffX,$y,$diffY,$colour,$enemyColour) = @_;
	my ($tmpX,$tmpY) = ($x+$diffX,$y+$diffY);
	while ($cells{$tmpX.$tmpY} eq $enemyColour) {
		$cells{$tmpX.$tmpY}=$colour;
		if($colour eq "black"){
			$quantityBlack++;
			$quantityWhite--;
			$canvas->delete("image".$tmpX.$tmpY);
			$canvas->createImage($tmpX,$tmpY,-image=>$black,-tags => "image".$tmpX.$tmpY);
		}
		else{
			$quantityWhite++;
			$quantityBlack--;
			$canvas->delete("image".$tmpX.$tmpY);
			$canvas->createImage($tmpX,$tmpY,-image=>$white,-tags => "image".$tmpX.$tmpY);
		}
		$tmpX+=$diffX;
		$tmpY+=$diffY;
	}
}

#######   AI   #######

sub easyAI {
	my($aiColour,$userColour) = ("white","black");
	&validMove($aiColour);
	my @a = keys %validMoves;
	if(not exists $a[0]){	
		$currentColour = "black";
		&validMove($currentColour);
		my @b = keys %validMoves;
		&result if(not exists $b[0]);
		$mw->messageBox(-message=>"Easy bot hasn't course", -type => "ok");
	}
	else{
		my $coord = shift @a;
		my @coords = @{$coordinates{$coord}};
		$quantityWhite++;
		$canvas->delete("image".$coords[0].$coords[1]);
		$canvas->createImage($coords[0],$coords[1],-image => $white,-tags => "image".$coords[0].$coords[1]);
		$cells{$coords[0].$coords[1]} = $aiColour;
		&eatEnemyChips($coords[0],$coords[1]);
		$quantityChipsOnTable++;
		$currentColour = $userColour;
	}
}

sub mediumAI {
	my($aiColour,$userColour) = ("white","black");
	&validMove($aiColour);
	my $coord; 
	my @a = keys %validMoves;
	if(not exists $a[0]){	
		$currentColour = "black";
		&validMove($currentColour);
		my @b = keys %validMoves;
		&result if(not exists $b[0]);
		$mw->messageBox(-message=>"Medium bot hasn't course", -type => "ok");
	}
	else{
		my $quan = $quantityEatenChips{$a[0]};
		$coord = $a[0];
		for my $i (@a){
			if($quantityEatenChips{$i} > $quan){
				$quan = $quantityEatenChips{$i};
				$coord = $i;
			}
		}
		my @coords = @{$coordinates{$coord}};
		$quantityWhite++;
		$canvas->delete("image".$coords[0].$coords[1]);
		$canvas->createImage($coords[0],$coords[1],-image => $white,-tags => "image".$coords[0].$coords[1]);
		$cells{$coords[0].$coords[1]} = $aiColour;
		&eatEnemyChips($coords[0],$coords[1]);
		$quantityChipsOnTable++;
		$currentColour = $userColour;
	}
}

sub hardAI {
	my($aiColour,$userColour) = ("white","black");
	&validMove($aiColour);
	my $coord; 
	my @a = keys %validMoves;
	if(not exists $a[0]){	
		$currentColour = "black";
		&validMove($currentColour);
		my @b = keys %validMoves;
		&result if(not exists $b[0]);
		$mw->messageBox(-message=>"Hard bot hasn't course", -type => "ok");
	}
	else{
		my $quan = $moveWeight{$a[0]};
		$coord = $a[0];
		for my $i (@a){
			if($moveWeight{$i} > $quan){
				$quan = $moveWeight{$i};
				$coord = $i;
			}
		}
		my @coords = @{$coordinates{$coord}};
		$quantityWhite++;
		$canvas->delete("image".$coords[0].$coords[1]);
		$canvas->createImage($coords[0],$coords[1],-image => $white,-tags => "image".$coords[0].$coords[1]);
		$cells{$coords[0].$coords[1]} = $aiColour;
		&eatEnemyChips($coords[0],$coords[1]);
		$quantityChipsOnTable++;
		$currentColour = $userColour;
	}		
}

sub isAngularCell($) {
	my $coord = shift;
	return (($coord == 450450) || ($coord == 3030) || ($coord == 30450) || ($coord == 45030));
}

sub isGoodEdgeCell($) {
	my $coord = shift;
	my @a = @{$coordinates{$coord}};
	if(($a[0] == 30) && ($a[1]>30) && ($a[1]<450)){
		return ((not exists $cells{$a[0].($a[1]-60)}) && (not exists $cells{$a[0].($a[1]+60)}));
	}
	elsif(($a[0] == 450) && ($a[1]>30) && ($a[1]<450)){
		return ((not exists $cells{$a[0].($a[1]-60)}) && (not exists $cells{$a[0].($a[1]+60)}));
	}
	elsif(($a[1] == 30) && ($a[0]>30) && ($a[0]<450)){
		return ((not exists $cells{($a[0]-60).$a[1]}) && (not exists $cells{($a[0]+60).$a[1]}));
	}
	elsif(($a[1] == 450) && ($a[0]>30) && ($a[0]<450)){
		return ((not exists $cells{($a[0]-60).$a[1]}) && (not exists $cells{($a[0]+60).$a[1]}));
	}
}

######################

sub result {
	if($quantityBlack > $quantityWhite){
		$mw->messageBox(-message=>"Black Player is Winner\n Score \nBlack: $quantityBlack \nWhite: $quantityWhite", -type => "ok");
	}elsif($quantityBlack < $quantityWhite){
		$mw->messageBox(-message=>"White Player is Winner\n Score \nBlack: $quantityBlack \nWhite: $quantityWhite", -type => "ok");
	}elsif($quantityBlack < $quantityWhite){
		$mw->messageBox(-message=>"The Winner isn't Present\n Score \nBlack: $quantityBlack \nWhite: $quantityWhite", -type => "ok");
	}
	&newGame($ai);
}

sub newGame($) {
	$mw->destroy;
	$ai = shift;
	$mw = MainWindow->new;
    $canvas = $mw->Canvas(qw/-width 480 -height 480/,-background => "#6A5ACD")->grid;
	$white=$mw->Photo(-file =>"white.gif");
	$black=$mw->Photo(-file =>"black.gif");
	($quantityChipsOnTable,$quantityWhite,$quantityBlack) = (4,2,2);
	%validMoves=();
	%validSides=();
	%quantityEatenChips=();
	%moveWeight=();
	$currentColour = "black";
	%cells=();
	@sides=();
	&createBoard($mw,$canvas);
	&createMenu($mw);
	for(my $y = 30;$y <= 450;$y+=60){
		for(my $x = 30;$x <= 450;$x+=60){
			$coordinates{($x.$y)}=[$x,$y];
		}
	}
	$canvas->CanvasBind("<Button-1>", [ \&move, Ev('x'), Ev('y')]);
}

sub newNetGame {
	$mw->destroy;
	$mw = MainWindow->new;
  $canvas = $mw->Canvas(qw/-width 480 -height 480/,-background => "#6A5ACD")->grid;
	$white=$mw->Photo(-file =>"white.gif");
	$black=$mw->Photo(-file =>"black.gif");
	($quantityChipsOnTable,$quantityWhite,$quantityBlack) = (4,2,2);
	%validMoves=();
	%validSides=();
	%quantityEatenChips=();
	%moveWeight=();
	$currentColour = "black";
	%cells=();
	@sides=();
	&createBoard($mw,$canvas);
	&createMenu($mw);
	for(my $y = 30;$y <= 450;$y+=60){
		for(my $x = 30;$x <= 450;$x+=60){
			$coordinates{($x.$y)}=[$x,$y];
		}
	}
	$canvas->CanvasBind("<Button-1>", [ \&move, Ev('x'), Ev('y')]);
}

sub netGameConnect{
	my $n='127.0.0.1';
  my $tl = $mw->Toplevel( ); 
  my $e = $tl->Entry(-textvariable =>$n)->pack(-expand => 1,-fill => 'x')->pack(-side=>'left');
  $tl->Button(-text => 'Ok', -command =>sub {
  	$n=$e->get(); 
  	$n=valid_ip($n); 
  	$tl->destroy;
  	$net = 1;
    $socket=IO::Socket::INET->new(PeerAddr  =>"$n",PeerPort=>'8001', Proto=>'udp') or die "Bad ip adress";
    say $n;
    my $data;
    my $select=IO::Select->new($socket);
    while (1){
      if ($select->can_read(0)) {
        say "lalala";
        $send=recv($socket,$data,1024,0);
		    my @data=split(/,/,$data);
		    say "@data";
		    $quantityChipsOnTable = $data[0];
		    $quantityBlack = $data[1];
		    $quantityWhite = $data[2];
		    $currentColour = $data[3];
		    my($x,$y) = ($data[4],$data[5]);
		    $currentColour = ($currentColour eq "black") ? "white" : "black";
		  	$cells{$x.$y} = $currentColour;
				&eatEnemyChips($x,$y);
				$currentColour = ($currentColour eq "black") ? "white" : "black";
      }
  	  $mw->update;
    }
  } )->pack(-side =>'left',-expand =>1,-fill=>'x');
}

sub netGameServer {
	$net=1;
	$socket = IO::Socket::INET->new(Proto=>'udp', LocalPort =>'8001') or die "$!";
	my $data;
  my $select=IO::Select->new($socket);
  while (1){
	  if ($select->can_read(0)) {
	    $send=recv($socket,$data,1024,0);
	    my @data=split(/,/,$data);
	    say "@data";
	    $quantityChipsOnTable = $data[0];
	    $quantityBlack = $data[1];
	    $quantityWhite = $data[2];
	    $currentColour = $data[3];
	    my($x,$y) = ($data[4],$data[5]);
	    $currentColour = ($currentColour eq "black") ? "white" : "black";
	  	$cells{$x.$y} = $currentColour;
			&eatEnemyChips($x,$y);
			$currentColour = ($currentColour eq "black") ? "white" : "black";
	  }
	  $mw->update;
  }
}

sub netGame($$){
  my ($x,$y) = @_;
  my $tmp;
  $tmp.="$quantityChipsOnTable,$quantityBlack,$quantityWhite,$currentColour,$x,$y";
  send($socket,$tmp,0,$send);       
}

sub valid_ip {
  my @oct = grep { $_ >= 0 && $_ <= 255 && $_ !~ /^0\d{1,2}$/ } split /\./, shift;
  return unless @oct == 4;
  return join('.', @oct);
}

##########################
&createBoard($mw,$canvas);
&createMenu($mw);

##########################

MainLoop;