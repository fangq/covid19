#!/usr/bin/env perl 
###############################################################################
#
# A GenBank GBFF file to JSON file converter
#
# Author:  Qianqian Fang <q.fang at neu.edu>
# License: BSD 3-clause
# Version: 0.4
# URL:     http://openjdata.org
# Github:  https://github.com/fangq/gene2019ncov/
#
###############################################################################

use strict;
use warnings;
use JSON 'to_json';
use Tie::IxHash;

if($#ARGV<0){
	print("gbff2json.pl - converting GenBank database file to a JSON/JData file
	Format: gbff2json.pl input.gbff > output.json\n");
	exit 0;
}

my ($key1, $key2, $key3)=("","","");
my ($lastobj,$value);

tie my %obj1, "Tie::IxHash";
tie my %obj2, "Tie::IxHash";
tie my %obj3, "Tie::IxHash";

while(<>){ # loop over each line of the input file
	next if(/^\s*$/);  # skip empty lines
	if(/^((\s*)(\S+)(\s+))(.*)/){  # line format: |$1=[(ws1=$2)key=$3(ws2=$4)]remaining=$5|
		my $ln=$_;
		$value=$4.$5;
		if(length($2)==0){ # a first level key start at the begining of the line
			if((keys %obj3)>0){ # attaching lower-level objects
				push(@{$obj2{$key2}},rmap(\%obj3));
				%obj3=();
				$key3="";
			}
			if((keys %obj2)>0){
				push(@{$obj1{$key1}},rmap(\%obj2));
				%obj2=();
				$key2="";
			}
			last if(/^\/\/$/);
			$key1=ucfirst(lc($3));
			push(@{$obj1{$key1}}, $5) if $5 ne '';
			$lastobj=$obj1{$3};
		}elsif(length($2)<12){ # a second level key starts within 12 spaces from the beginning
			if((keys %obj3)>0){  # attaching lower-level objects
				push(@{$obj2{$key2}},rmap(\%obj3));
				%obj3=();
				$key3="";
			}
			push(@{$obj2{$3}}, $5) if $5 ne '';
			$key2=$3;
			$lastobj=$obj2{$3};
		}elsif($3 =~/^\/([a-z_]+)="{0,1}(.*)$/){ # a 3rd level key starts with "/keyname=..."
			$key3=$1;
			$value=$2.$value;
			$value=~s/"*\s*$//g;
			push(@{$obj3{$key3}},$value);
			$lastobj=$obj3{$key3};
		}else{                       # appending line to the last object
			$ln=~s/^\s+|"*\s+$//g;
			if(join('',map { ref() eq 'HASH' ? 1 : 0} $lastobj) ==0){
				${$lastobj}[0].= $ln;
			}else{
				push(@{$lastobj}, $ln);
			}
		}
	}
}
%obj1=%{rmap(\%obj1)};

# concatenate ORIGIN hash values into a single string
if($obj1{'Origin'}){
	$obj1{'Origin'}=join('',map { $obj1{'Origin'}{$_}} keys %{$obj1{'Origin'}});
	$obj1{'Origin'}=~s/\s//g;
}

print to_json(\%obj1,{utf8 => 1, pretty => 1});

sub rmap{
	my ($obj)=@_;
	tie my %res, "Tie::IxHash";
	%res= map { $_ => (ref($obj->{$_}) eq 'ARRAY' &&  @{$obj->{$_}}>0) 
	              ? ( @{$obj->{$_}}==1 ? ${ $obj->{$_} }[0] : 
		           (@{$obj->{$_}} %2 ==0 ? { @{ $obj->{$_} } } : $obj->{$_} ) )
		      : $obj->{$_}
	         } keys %{$obj};
	return \%res;
}