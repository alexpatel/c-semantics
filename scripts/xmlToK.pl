#!/usr/bin/perl
use strict;
use File::Basename;
use Encode;
use MIME::Base64;
use XML::LibXML::Reader;

binmode STDOUT, ":utf8";
binmode STDIN, ":utf8";

# not handling the case of multiple cdatas 
# can use 'erase' to get rid of junk cells

my $STRING = "#";
my $ID = "#";
my $BOOL = '#';
my $RAT = '#';

#########################################################
# you may want to configure things inside this section
use constant KLIST_IDENTITY => ".KList";
use constant KLIST_SEPARATOR => ",, ";

my $ltl = "";

# might want to return, say, "'$name"
sub nameToLabel {
	my ($name) = (@_);
	return "'$name";
}
#########################################################
my %escapeMap = (
	"\007" => '\\a',
	"\010" => '\\b',
	"\011" => '\\t',
	"\012" => '\\n',
	"\013" => '\\v',
	"\014" => '\\f',
	"\015" => '\\r',
	'"' => '\\"',
	'\\' => '\\\\'
);

# my $xso = XML::SimpleObject->new( $parser->parsefile($file) );

my $input = join("", <STDIN>);
#print "$input\n";
# my $parser = XML::Parser->new(ErrorContext => 2, Style => "Tree");
#$parser->parse($input);
# my $xso = XML::SimpleObject->new($parser->parse($input));

# sub replaceWith {
	# my ($elt, $label) = (@_);
	# $elt->wrap_in($label);
	# my $parent = $elt->parent;
	# $elt->erase;
	# return $parent;
# }

# my %labelMap = (
	# List => '_::_',
# );

my %ignoreThese = (	
	'Filename' => 1,
	'Lineno' => 1,
	'Byteno' => 1,
	'OffsetStart' => 1,
	'OffsetEnd' => 1,
	'Ident' => 1,
	'BlockId' => 1,
	'SwitchId' => 1,
	'Lineno' => 1,
	'CompoundLiteralId' => 1,
	'CaseId' => 1,
	'ForId' => 1,
	'SourceCode' => 1,
	'DeclarationType' => 1,
	'Variable' => 1,
	'Paren' => 1,
	'Significand' => 1,
	'Exponent' => 1,
	'TypeQualifier' => 1,
	'StorageSpecifier' => 1,
	'FunctionSpecifier' => 1,
	'Specifiers' => 1,
	'TypeSpecifier' => 1,
	'LocalDefinition' => 1,
	'IntLiteral' => 1,
	'FloatLiteral' => 1,
	'ForClauseDeclaration' => 1,
);

# foreach my $key (keys %labelMap) {
	# $handlers->{$key} = sub { $_->set_tag($labelMap{$key}); };	
# }

my $reader = new XML::LibXML::Reader(string => $input) or die "cannot create XML::LibXML::Reader object\n";
$reader->read;

if (! ($reader->name eq "TranslationUnit")) {
	die "XML: Expected first entry to be 'TranslationUnit'.";
}
$reader->nextElement('RawData');
# print STDERR "At " . $reader->name . "\n";
my $filename = getRawData($reader);
if ($filename eq ""){
	die "Could not find the filename in the XML\n";
}

# print "---kccMarker\n";
my $filenameTerm = "$STRING $filename" . paren(KLIST_IDENTITY);
my @args = ();
push (@args, $filenameTerm);

$reader->nextElement;
# print STDERR "At " . $reader->name . "\n";
push (@args, xmlToK($reader));

#$reader->nextElement;
# print STDERR "At " . $reader->name . "\n";
push (@args, xmlToK($reader));

$reader->nextElement('RawData');
# print STDERR "At " . $reader->name . "\n";
my $sourceCode = getRawData($reader);
push (@args, "$STRING $sourceCode" . paren(KLIST_IDENTITY));
my $tu = paren(join(KLIST_SEPARATOR, @args));
#print "eq TranslationUnitName($filenameTerm)(.KList) = " . nameToLabel('TranslationUnit') . $tu . ".\n";
print nameToLabel('TranslationUnit') . $tu ;
# if ($ltl ne "") {
# 	print $ltl;
# }


sub printStatus {
	my ($reader) = (@_);
	print "visit: " . $reader->name . "\n";
	print "isempty: " . $reader->isEmptyElement . "\n";
	print "value: " . $reader->value . "\n";
	print "type: " . $reader->nodeType . "\n";
}

# this function tries to figure out what kind of a node we're looking at, then delegates the conversion to another function
sub xmlToK {
	my ($reader) = (@_);
	#printStatus($reader);
	if (! ($reader->nodeType == XML_READER_TYPE_CDATA)) {
		my $depth = $reader->depth;
		my ($inNextState, $retval) = elementToK($reader);
		if (!$inNextState) {
			$reader->nextElement;
		}
		return $retval;
	}
	return "";
}

sub elementToK {
	my ($reader) = (@_);
	my $inNextState = 0;
	my $label = $reader->name;
	if (exists($ignoreThese{$label})) {
		return ($inNextState, undef);
	}
	my $prefix = "";
	my $suffix = "";
	if ($label eq "RawData") {
		return ($inNextState, rawdataToK($reader));
	}
	if ($label eq 'List') {
		$label = "_::_";  # chathhorn: never used?
	} elsif ($label eq 'NewList') {
		$label = "klist";
		$prefix = '(_`(_`)(KList2KLabel_(';
		$suffix = '), .KList))';
	# } elsif ($label eq 'Identifier') {
		# $reader->nextElement;
		# my $rawData = getRawData($reader);
		# my $ident = 'Identifier' . paren($rawData);
		# my $id = paren($ident);
		# return ($inNextState, $id);
	} elsif ($label eq 'WStringLiteral') {
		$reader->nextElement;
		$reader->read;
		my $str = escapeWString($reader->value);
		my $ident = "'WStringLiteral" . paren(paren($str));
		return ($inNextState, $ident);
	} elsif ($label eq 'Variadic') {
		return ($inNextState, paren("$BOOL true") . paren(KLIST_IDENTITY));
	} elsif ($label eq 'NotVariadic') {
		return ($inNextState, paren("$BOOL false") . paren(KLIST_IDENTITY));
	} elsif ($label eq 'U'
            || $label eq 'L'
            || $label eq 'LL'
            || $label eq 'UL'
            || $label eq 'ULL') {
            $label = 'Const' . $label;
      }

	my @klist = ();
	my $depth = $reader->depth;
	$reader->nextElement;
	if ($reader->depth > $depth) {
		do {
			my $childResult = xmlToK($reader);
			if ($childResult) {
				push (@klist, $childResult);
			}
		} while ($reader->depth > $depth) # while ($reader->nextSiblingElement == 1);
	}
	$inNextState = 1;
	
	my $numElements = scalar @klist;
	if ($numElements == 0) {
		push (@klist, KLIST_IDENTITY);
	}
	my $kterm = paren(join(KLIST_SEPARATOR, @klist));
	
	if ($label eq 'LTLAnnotation') {
		$ltl .= "eq 'LTLAnnotation($klist[0]) = ";
		shift (@klist);
		$ltl .= paren(join(KLIST_SEPARATOR, @klist)) . " .\n";
		return ($inNextState, "(.).K");
	}
	return ($inNextState, nameToLabel($label) . $prefix . $kterm . $suffix);
}

sub rawdataToK {
	my ($reader) = (@_);
	my $sort = $reader->getAttribute('sort');
	if ($sort eq 'Int') { $sort = 'Rat'; }
	my $data = getRawData($reader);
	return "#" . paren($data) . paren(KLIST_IDENTITY);
}
sub getRawData {
	my ($reader) = (@_);
	my $sort = $reader->getAttribute('sort');
	my $data = "";
	$reader->read;
	
	if ($sort eq 'String') {
		$data = '"' . escapeString($reader->value) . '"';
	} elsif ($sort eq 'Int') {
		$data = $reader->value;
	}  elsif ($sort eq 'Float') {
		$data = $reader->value;
	} else {
		return "unknown raw data";
	}
	return $data;
}


sub escapeSingleCharacter {
	my ($char) = (@_);
	
	if (exists($escapeMap{$char})) {
		return $escapeMap{$char};
	} elsif ($char =~ /[\x20-\x7E]/) {
		return $char;
	} else {
		my $ord = ord($char);
		return '\\' . sprintf("%03o", $ord) ;
	}
}

sub escapeString {
	my ($str) = (@_);
	my $decoded = decode_base64($str);
	my @charArray = split(//, $decoded);
	my @newArray = map(escapeSingleCharacter($_), @charArray) ;
	return join('', @newArray);
}


sub escapeWString {
	my ($str) = (@_);
	my $decoded = decode_base64($str);
	my $retval = '_`(_`)(kList("\'klist"), (';
	utf8::decode($decoded);
	my @charArray = split(//, $decoded);
	for my $c (@charArray) {
		utf8::encode($c);
		my @charPartArray = split(//, $c);
		my $single = 0;
		for my $cp (@charPartArray) {
			$single = ($single << 8) + ord($cp);
		}
		$retval .= "$RAT $single" . paren(KLIST_IDENTITY) . KLIST_SEPARATOR . " ";
	}
	
	$retval .= ".KList))";
	return $retval;
}

sub paren {
	my ($str) = (@_);
	return "($str)";
}
