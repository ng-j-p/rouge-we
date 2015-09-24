#!/usr/bin/perl -w
# Version: ROUGE-WE v1.0
# Date:    2015 Aug 3
# Author:  Jun-Ping Ng (http://wing.comp.nus.edu.sg/~junping)
# Download:
#   The latest version of this code base can always be downloaded from
#   https://github.com/ng-j-p/rouge-we
# Description:
#   This script is the implementation for ROUGe-WE, as described in
#     Better Summarization Evaluation with Word Embeddings for ROUGE
#       Jun-Ping Ng and Viktoria Abrecht
#       In Proceedings of Conference on Empirical Methods in Natural
#       Language Processing (EMNLP 2015)
#
#   It is based on ROUGE v1.5.5 (http://www.berouge.com/) by
#      Chin-Yew Lin.
#   Original license of ROUGE is found below this pre-amble.
#
# Licensing:
#   ROUGE-WE v1.0 is released under the MIT license (https://github.com/ng-j-p/rouge-we/blob/master/LICENSE)
#
# Disclaimer:
#   THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
#   IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
#   FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
#   AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
#   LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
#   OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
#   SOFTWARE.


## Original license distributed with ROUGE v1.5.5
#################################################
# Version:     ROUGE v1.5.5
# Date:        05/26/2005,05/19/2005,04/26/2005,04/03/2005,10/28/2004,10/25/2004,10/21/2004
# Author:      Chin-Yew Lin
# Description: Given an evaluation description file, for example: test.xml,
#              this script computes the averages of the average ROUGE scores for 
#              the evaluation pairs listed in the ROUGE evaluation configuration file.
#              For more information, please see:
#              http://www.isi.edu/~cyl/ROUGE
#              For more information about Basic Elements, please see:
#              http://www.isi.edu/~cyl/BE
#
# COPYRIGHT (C) UNIVERSITY OF SOUTHERN CALIFORNIA, 2002,2003,2004
# University of Southern California                                           
# Information Sciences Institute                                              
# 4676 Admiralty Way                                                          
# Marina Del Rey, California 90292-6695                                       
#                                                                             
# This software was partially developed under SPAWAR Grant No.
# N66001-00-1-8916 , and  the Government holds license rights under
# DAR 7-104.9(a)(c)(1).  It is  
# transmitted outside of the University of Southern California only under 
# written license agreements or software exchange agreements, and its use   
# is limited by these agreements.  At no time shall any recipient use       
# this software in any manner which conflicts or interferes with the        
# governmental license rights or other provisions of the governing           
# agreement under which it is obtained.  It is supplied "AS IS," without     
# any warranties of any kind.  It is furnished only on the basis that any    
# party who receives it indemnifies and holds harmless the parties who       
# furnish and originate it against any claims, demands or liabilities        
# connected with using it, furnishing it to others or providing it to a      
# third party.  THIS NOTICE MUST NOT BE REMOVED FROM THE SOFTWARE,
# AND IN THE EVENT THAT THE SOFTWARE IS DIVIDED, IT SHOULD BE
# ATTACHED TO EVERY PART.
#
# Contributor to its design is Chin-Yew Lin.
##################################
# End original license from ROUGE v1.5.5
#################################


## Edits from ROUGE-1.5.5 marked out with EDIT-WE
##

## EDIT-WE 
use LWP::UserAgent;
use HTTP::Request::Common;
use HTTP::Response;
use JSON qw( decode_json );
## EDIT-WE 
use XML::DOM;
use DB_File;
use Getopt::Std;
use Scalar::Util qw( looks_like_number );
#-------------------------------------------------------------------------------------
use vars qw($opt_a $opt_b $opt_c $opt_d $opt_e $opt_f $opt_h $opt_H $opt_m $opt_n $opt_p $opt_s $opt_t $opt_l $opt_v $opt_w $opt_2 $opt_u $opt_x $opt_U $opt_3 $opt_M $opt_z);
my $usageFull="$0\n         [-a (evaluate all systems)] 
         [-c cf]
         [-d (print per evaluation scores)] 
         [-e ROUGE_EVAL_HOME] 
         [-h (usage)] 
         [-H (detailed usage)] 
         [-b n-bytes|-l n-words] 
         [-m (use Porter stemmer)] 
         [-n max-ngram] 
         [-s (remove stopwords)] 
         [-r number-of-samples (for resampling)] 
         [-2 max-gap-length (if < 0 then no gap length limit)] 
         [-3 <H|HM|HMR|HM1|HMR1|HMR2> (for scoring based on BE)] 
         [-u (include unigram in skip-bigram) default no)] 
         [-U (same as -u but also compute regular skip-bigram)] 
         [-w weight (weighting factor for WLCS)] 
         [-v (verbose)] 
         [-x (do not calculate ROUGE-L)] 
         [-f A|B (scoring formula)] 
         [-p alpha (0 <= alpha <=1)] 
         [-t 0|1|2 (count by token instead of sentence)] 
         [-z <SEE|SPL|ISI|SIMPLE>] 
         <ROUGE-eval-config-file> [<systemID>]\n
".
  "ROUGE-eval-config-file: Specify the evaluation setup. Three files come with the ROUGE evaluation package, i.e.\n".
  "          ROUGE-test.xml, verify.xml, and verify-spl.xml are good examples.\n".
  "systemID: Specify which system in the ROUGE-eval-config-file to perform the evaluation.\n".
  "          If '-a' option is used, then all systems are evaluated and users do not need to\n".
  "          provide this argument.\n".
  "Default:\n".
  "  When running ROUGE without supplying any options (except -a), the following defaults are used:\n".
  "  (1) ROUGE-L is computed;\n".
  "  (2) 95% confidence interval;\n".
  "  (3) No stemming;\n".
  "  (4) Stopwords are inlcuded in the calculations;\n".
  "  (5) ROUGE looks for its data directory first through the ROUGE_EVAL_HOME environment variable. If\n".
  "      it is not set, the current directory is used.\n".
  "  (6) Use model average scoring formula.\n".
  "  (7) Assign equal importance of ROUGE recall and precision in computing ROUGE f-measure, i.e. alpha=0.5.\n".
  "  (8) Compute average ROUGE by averaging sentence (unit) ROUGE scores.\n".
  "Options:\n".
  "  -2: Compute skip bigram (ROGUE-S) co-occurrence, also specify the maximum gap length between two words (skip-bigram)\n".
  "  -u: Compute skip bigram as -2 but include unigram, i.e. treat unigram as \"start-sentence-symbol unigram\"; -2 has to be specified.\n".
  "  -3: Compute BE score. Currently only SIMPLE BE triple format is supported.\n".
  "      H    -> head only scoring (does not applied to Minipar-based BEs).\n".
  "      HM   -> head and modifier pair scoring.\n".
  "      HMR  -> head, modifier and relation triple scoring.\n".
  "      HM1  -> H and HM scoring (same as HM for Minipar-based BEs).\n".
  "      HMR1 -> HM and HMR scoring (same as HMR for Minipar-based BEs).\n".
  "      HMR2 -> H, HM and HMR scoring (same as HMR for Minipar-based BEs).\n".
  "  -a: Evaluate all systems specified in the ROUGE-eval-config-file.\n".
  "  -c: Specify CF\% (0 <= CF <= 100) confidence interval to compute. The default is 95\% (i.e. CF=95).\n".
  "  -d: Print per evaluation average score for each system.\n".
  "  -e: Specify ROUGE_EVAL_HOME directory where the ROUGE data files can be found.\n".
  "      This will overwrite the ROUGE_EVAL_HOME specified in the environment variable.\n".
  "  -f: Select scoring formula: 'A' => model average; 'B' => best model\n".
  "  -h: Print usage information.\n".
  "  -H: Print detailed usage information.\n".
  "  -b: Only use the first n bytes in the system/peer summary for the evaluation.\n".
  "  -l: Only use the first n words in the system/peer summary for the evaluation.\n".
  "  -m: Stem both model and system summaries using Porter stemmer before computing various statistics.\n".
  "  -n: Compute ROUGE-N up to max-ngram length will be computed.\n".
  "  -p: Relative importance of recall and precision ROUGE scores. Alpha -> 1 favors precision, Alpha -> 0 favors recall.\n".
  "  -s: Remove stopwords in model and system summaries before computing various statistics.\n".
  "  -t: Compute average ROUGE by averaging over the whole test corpus instead of sentences (units).\n".
  "      0: use sentence as counting unit, 1: use token as couting unit, 2: same as 1 but output raw counts\n".
  "      instead of precision, recall, and f-measure scores. 2 is useful when computation of the final,\n".
  "      precision, recall, and f-measure scores will be conducted later.\n".
  "  -r: Specify the number of sampling point in bootstrap resampling (default is 1000).\n".
  "      Smaller number will speed up the evaluation but less reliable confidence interval.\n".
  "  -w: Compute ROUGE-W that gives consecutive matches of length L in an LCS a weight of 'L^weight' instead of just 'L' as in LCS.\n".
  "      Typically this is set to 1.2 or other number greater than 1.\n".
  "  -v: Print debugging information for diagnositic purpose.\n".
  "  -x: Do not calculate ROUGE-L.\n".
  "  -z: ROUGE-eval-config-file is a list of peer-model pair per line in the specified format (SEE|SPL|ISI|SIMPLE).\n";

my $usage="$0\n         [-a (evaluate all systems)] 
         [-c cf]
         [-d (print per evaluation scores)] 
         [-e ROUGE_EVAL_HOME] 
         [-h (usage)] 
         [-H (detailed usage)] 
         [-b n-bytes|-l n-words] 
         [-m (use Porter stemmer)] 
         [-n max-ngram] 
         [-s (remove stopwords)] 
         [-r number-of-samples (for resampling)] 
         [-2 max-gap-length (if < 0 then no gap length limit)] 
         [-3 <H|HM|HMR|HM1|HMR1|HMR2> (for scoring based on BE)] 
         [-u (include unigram in skip-bigram) default no)] 
         [-U (same as -u but also compute regular skip-bigram)] 
         [-w weight (weighting factor for WLCS)] 
         [-v (verbose)] 
         [-x (do not calculate ROUGE-L)] 
         [-f A|B (scoring formula)] 
         [-p alpha (0 <= alpha <=1)] 
         [-t 0|1|2 (count by token instead of sentence)] 
         [-z <SEE|SPL|ISI|SIMPLE>] 
         <ROUGE-eval-config-file> [<systemID>]
";
getopts('ahHb:c:de:f:l:mMn:p:st:r:2:3:w:uUvxz:');
my $systemID;

## EDIT-WE 
my $ua = LWP::UserAgent->new;
my $server_endpoint = "http://127.0.0.1:8888/word2vecdiff";
## EDIT-WE 

die $usageFull if defined($opt_H);
die $usage if defined($opt_h)||@ARGV==0;
die "Please specify the ROUGE configuration file or use option '-h' for help\n" if(@ARGV==0);
if(@ARGV==1&&defined($opt_z)) {
  $systemID="X"; # default system ID
}
elsif(@ARGV==1&&!defined($opt_a)) {
  die "Please specify a system ID to evaluate or use option '-a' to evaluate all systems. For more information, use option '-h'.\n";
}
elsif(@ARGV==2) {
  $systemID=$ARGV[1];
}
if(defined($opt_e)) {
  $stopwords="$opt_e/smart_common_words.txt";
  $wordnetDB="$opt_e/WordNet-2.0.exc.db";
}
else {
  if(exists($ENV{"ROUGE_EVAL_HOME"})) {
    $stopwords="$ENV{\"ROUGE_EVAL_HOME\"}/smart_common_words.txt";
    $wordnetDB="$ENV{\"ROUGE_EVAL_HOME\"}/WordNet-2.0.exc.db";
  }
  elsif(exists($ENV{"RED_EVAL_HOME"})) {
    $stopwords="$ENV{\"RED_EVAL_HOME\"}/smart_common_words.txt";
    $wordnetDB="$ENV{\"RED_EVAL_HOME\"}/WordNet-2.0.exc.db";
  }
  else {
    # if no environment variable exists then assume data files are in the current directory
    $stopwords="smart_common_words.txt";
    $wordnetDB="WordNet-2.0.exc.db";
  }
}

if(defined($opt_s)) {
  $useStopwords=0; # do not use stop words
}
else {
  $useStopwords=1; # use stop words
}

if(defined($opt_l)&&defined($opt_b)) {
  die "Please specify length limit in words or bytes but not both.\n";
}

if(defined($opt_l)) {
  $lengthLimit=$opt_l;
  $byteLimit=0;   # no byte limit
}
elsif(defined($opt_b)) {
  $lengthLimit=0; # no length limit in words
  $byteLimit=$opt_b;
}
else {
  $byteLimit=0;   # no byte limit
  $lengthLimit=0; # no length limit
}

unless(defined($opt_c)) {
  $opt_c=95;
}
else {
  if($opt_c<0||$opt_c>100) {
    die "Confidence interval should be within 0 and 100. Use option -h for more details.\n";
  }
}

if(defined($opt_w)) {
  if($opt_w>0) {
    $weightFactor=$opt_w;
  }
  else {
    die "ROUGE-W weight factor must greater than 0.\n";
  }
}
#unless(defined($opt_n)) {
#    $opt_n=4; # default maximum ngram is 4
#}
if(defined($opt_v)) {
  $debug=1;
}
else {
  $debug=0;
}

if(defined($opt_r)) {
  $numOfResamples=$opt_r;
}
else {
  $numOfResamples=1000;
}

if(defined($opt_2)) {
  $skipDistance=$opt_2;
}

if(defined($opt_3)) {
  $BEMode=$opt_3;
}

if(defined($opt_f)) {
  $scoreMode=$opt_f;
}
else {
  $scoreMode="A"; # default: use model average scoring formula
}

if(defined($opt_p)) {
  $alpha=$opt_p;
  if($alpha<0||
     $alpha>1) {
    die "Relative importance of ROUGE recall and precision has to be between 0 and 1 inclusively.\n";
  }
}
else {
  $alpha=0.5; # default is equal importance of ROUGE recall and precision
}

if(defined($opt_t)) {
  # make $opt_t as undef when appropriate option is given
  # when $opt_t is undef, sentence level average will be used
  if($opt_t==0) {
    $opt_t=undef;
  }
  elsif($opt_t!=1&&
	$opt_t!=2) {
    $opt_t=undef; # other than 1 or 2, let $opt_t to be undef
  }
}

if(defined($opt_z)) {
  # If opt_z is specified, the user has to specify a system ID that
  # is used for identification therefore -a option is not allowed.
  # Here we make it undef.
  $opt_a=undef;
}
#-------------------------------------------------------------------------------------
# Setup ROUGE scoring parameters
%ROUGEParam=();   # ROUGE scoring parameter
if(defined($lengthLimit)) {
  $ROUGEParam{"LENGTH"}=$lengthLimit;
}
else {
  $ROUGEParam{"LENGTH"}=undef;
}
if(defined($byteLimit)) {
  $ROUGEParam{"BYTE"}=$byteLimit;
}
else {
  $ROUGEParam{"BYTE"}=undef;
}
if(defined($opt_n)) { # ngram size
  $ROUGEParam{"NSIZE"}=$opt_n;
}
else {
  $ROUGEParam{"NSIZE"}=undef;
}
if(defined($weightFactor)) {
  $ROUGEParam{"WEIGHT"}=$weightFactor;
}
else {
  $ROUGEParam{"WEIGHT"}=undef;
}
if(defined($skipDistance)) {
  $ROUGEParam{"SD"}=$skipDistance;
}
else {
  $ROUGEParam{"SD"}=undef;
}
if(defined($scoreMode)) {
  $ROUGEParam{"SM"}=$scoreMode;
}
else {
  $ROUGEParam{"SM"}=undef;
}
if(defined($alpha)) {
  $ROUGEParam{"ALPHA"}=$alpha;
}
else {
  $ROUGEParam{"ALPHA"}=undef;
}
if(defined($opt_t)) {
  $ROUGEParam{"AVERAGE"}=$opt_t;
}
else {
  $ROUGEParam{"AVERAGE"}=undef;
}
if(defined($opt_3)) {
  $ROUGEParam{"BEMODE"}=$opt_3;
}
else {
  $ROUGEParam{"BEMODE"}=undef;
}
#-------------------------------------------------------------------------------------
# load stopwords
%stopwords=();
open(STOP,$stopwords)||die "Cannot open $stopwords\n";
while(defined($line=<STOP>)) {
  chomp($line);
  $stopwords{$line}=1;
}
close(STOP);
# load WordNet database
if(-e "$wordnetDB") {
  tie %exceptiondb,'DB_File',"$wordnetDB",O_RDONLY,0440,$DB_HASH or
    die "Cannot open exception db file for reading: $wordnetDB\n";
}
else {
  die "Cannot open exception db file for reading: $wordnetDB\n";
}
#-------------------------------------------------------------------------------------
# Initialize Porter Stemmer
&initialise();
#-------------------------------------------------------------------------------------
# Read and parse the document
my $parser = new XML::DOM::Parser;
my $doc;
unless(defined($opt_z)) {
  $doc=$parser->parsefile($ARGV[0]);
}
else {
  open($doc,$ARGV[0])||die "Cannot open $ARGV[0]\n";
}
%ROUGEEvals=();
@ROUGEEvalIDs=();
%ROUGEPeerIDTable=();
@allPeerIDs=();
%knownMissing=(); # remember missing submission already known
if(defined($doc)) {
  # read evaluation description file
  &readEvals(\%ROUGEEvals,\@ROUGEEvalIDs,\%ROUGEPeerIDTable,$doc,undef);
  # print evaluation configuration
  if(defined($opt_z)) {
    if(defined($ARGV[1])) {
      $systemID=$ARGV[1];
    }
    else {
      $systemID="X"; # default system ID in BE file list evaluation mode
    }
    push(@allPeerIDs,$systemID);
  }
  else {
    unless(defined($opt_a)) {
      $systemID=$ARGV[1];
      push(@allPeerIDs,$systemID);
    }
    else {
      # run evaluation for each peer listed in the description file
      @allPeerIDs=sort (keys %ROUGEPeerIDTable);
    }
  }
  foreach $peerID (@allPeerIDs) {
    %testIDs=();
    #	print "\@PEER($peerID)--------------------------------------------------\n";
    if(defined($opt_n)) {
      # evaluate a specific peer
      # compute ROUGE score up to $opt_n-gram
      for($n=1;$n<=$opt_n;$n++) {
	my (%ROUGEScores,%ROUGEAverages);
	
	%ROUGEScores=();
	foreach $e (@ROUGEEvalIDs) {
	  if($debug) {
	    print "\@Eval ($e)\n";
	  }
	  $ROUGEParam{"NSIZE"}=$n;
	  &computeROUGEX("N",\%ROUGEScores,$e,$ROUGEEvals{$e},$peerID,\%ROUGEParam);
	}
	# compute averages
	%ROUGEAverages=();
	&computeAverages(\%ROUGEScores,\%ROUGEAverages,$opt_t);
	&printResults($peerID,\%ROUGEAverages,\%ROUGEScores,"ROUGE-$n",$opt_c,$opt_t,$opt_d);
      }
    }
    unless(defined($opt_x)||defined($opt_3)) {
      #-----------------------------------------------
      # compute LCS score
      %ROUGEScores=();
      foreach $e (@ROUGEEvalIDs) {
	&computeROUGEX("L",\%ROUGEScores,$e,$ROUGEEvals{$e},$peerID,\%ROUGEParam);
      }
      # compute averages
      %ROUGEAverages=();
      &computeAverages(\%ROUGEScores,\%ROUGEAverages,$opt_t);
      &printResults($peerID,\%ROUGEAverages,\%ROUGEScores,"ROUGE-L",$opt_c,$opt_t,$opt_d);
    }
    if(defined($opt_w)) {
      #-----------------------------------------------
      # compute WLCS score
      %ROUGEScores=();
      foreach $e (@ROUGEEvalIDs) {
	&computeROUGEX("W",\%ROUGEScores,$e,$ROUGEEvals{$e},$peerID,\%ROUGEParam);
      }
      # compute averages
      %ROUGEAverages=();
      &computeAverages(\%ROUGEScores,\%ROUGEAverages,$opt_t);
      &printResults($peerID,\%ROUGEAverages,\%ROUGEScores,"ROUGE-W-$weightFactor",$opt_c,$opt_t,$opt_d);
    }
    if(defined($opt_2)) {
      #-----------------------------------------------
      # compute skip bigram score
      %ROUGEScores=();
      foreach $e (@ROUGEEvalIDs) {
	&computeROUGEX("S",\%ROUGEScores,$e,$ROUGEEvals{$e},$peerID,\%ROUGEParam);
      }
      # compute averages
      %ROUGEAverages=();
      &computeAverages(\%ROUGEScores,\%ROUGEAverages,$opt_t);
      if($skipDistance>=0) {
	if(defined($opt_u)) {
	  &printResults($peerID,\%ROUGEAverages,\%ROUGEScores,"ROUGE-SU$skipDistance",$opt_c,$opt_t,$opt_d);
	}
	elsif(defined($opt_U)) {
	  # print regular skip bigram results
	  &printResults($peerID,\%ROUGEAverages,\%ROUGEScores,"ROUGE-S$skipDistance",$opt_c,$opt_t,$opt_d);
	  #-----------------------------------------------
	  # compute skip bigram with unigram extension score
	  $opt_u=1;
	  %ROUGEScores=();
	  foreach $e (@ROUGEEvalIDs) {
	    &computeROUGEX("S",\%ROUGEScores,$e,$ROUGEEvals{$e},$peerID,\%ROUGEParam);
	  }
	  $opt_u=undef;
	  # compute averages
	  %ROUGEAverages=();
	  &computeAverages(\%ROUGEScores,\%ROUGEAverages,$opt_t);
	  &printResults($peerID,\%ROUGEAverages,\%ROUGEScores,"ROUGE-SU$skipDistance",$opt_c,$opt_t,$opt_d);
	}
	else {
	  &printResults($peerID,\%ROUGEAverages,\%ROUGEScores,"ROUGE-S$skipDistance",$opt_c,$opt_t,$opt_d);
	}
      }
      else {
	if(defined($opt_u)) {
	  &printResults($peerID,\%ROUGEAverages,\%ROUGEScores,"ROUGE-SU*",$opt_c,$opt_t,$opt_d);
	}
	else {
	  &printResults($peerID,\%ROUGEAverages,\%ROUGEScores,"ROUGE-S*",$opt_c,$opt_t,$opt_d);
	  if(defined($opt_U)) {
	    #-----------------------------------------------
	    # compute skip bigram with unigram extension score
	    $opt_u=1;
	    %ROUGEScores=();
	    foreach $e (@ROUGEEvalIDs) {
	      &computeROUGEX("S",\%ROUGEScores,$e,$ROUGEEvals{$e},$peerID,\%ROUGEParam);
	    }
	    $opt_u=undef;
	    # compute averages
	    %ROUGEAverages=();
	    &computeAverages(\%ROUGEScores,\%ROUGEAverages,$opt_t);
	    &printResults($peerID,\%ROUGEAverages,\%ROUGEScores,"ROUGE-SU*",$opt_c,$opt_t,$opt_d);
	  }
	}
      }
    }
    if(defined($opt_3)) {
      #-----------------------------------------------
      # compute Basic Element triple score
      %ROUGEScores=();
      foreach $e (@ROUGEEvalIDs) {
	&computeROUGEX("BE",\%ROUGEScores,$e,$ROUGEEvals{$e},$peerID,\%ROUGEParam);
      }
      # compute averages
      %ROUGEAverages=();
      &computeAverages(\%ROUGEScores,\%ROUGEAverages,$opt_t);
      &printResults($peerID,\%ROUGEAverages,\%ROUGEScores,"ROUGE-BE-$BEMode",$opt_c,$opt_t,$opt_d);
    }
  }
}
else {
  die "Document undefined\n";
}
if(defined($opt_z)) {
  close($doc);
}
untie %exceptiondb;

sub printResults {
  my $peerID=shift;
  my $ROUGEAverages=shift;
  my $ROUGEScores=shift;
  my $methodTag=shift;
  my $opt_c=shift;
  my $opt_t=shift;
  my $opt_d=shift;

  print "---------------------------------------------\n";
  if(!defined($opt_t)||$opt_t==1) {
    print "$peerID $methodTag Average_R: $ROUGEAverages->{'AvgR'} ";
    print "($opt_c\%-conf.int. $ROUGEAverages->{'CIAvgL_R'} - $ROUGEAverages->{'CIAvgU_R'})\n";
    print "$peerID $methodTag Average_P: $ROUGEAverages->{'AvgP'} ";
    print "($opt_c\%-conf.int. $ROUGEAverages->{'CIAvgL_P'} - $ROUGEAverages->{'CIAvgU_P'})\n";
    print "$peerID $methodTag Average_F: $ROUGEAverages->{'AvgF'} ";
    print "($opt_c\%-conf.int. $ROUGEAverages->{'CIAvgL_F'} - $ROUGEAverages->{'CIAvgU_F'})\n";
  }
  else {
    print "$peerID $methodTag M_count: ";
    print int($ROUGEAverages->{'M_cnt'});
    print " P_count: ";
    print int($ROUGEAverages->{'P_cnt'});
    print " H_count: ";
    print int($ROUGEAverages->{'H_cnt'});
    print "\n";
  }
  if(defined($opt_d)) {
    print ".............................................\n";
    &printPerEvalData($ROUGEScores,"$peerID $methodTag Eval");
  }
}

sub bootstrapResampling {
  my $scores=shift;
  my $instances=shift;
  my $seed=shift;
  my $opt_t=shift;
  my $sample;
  my ($i,$ridx);
  
  # Use $seed to seed the random number generator to make sure
  # we have the same random sequence every time, therefore a
  # consistent estimation of confidence interval in different runs.
  # This is not necessary. To ensure a consistent result in reporting
  # results using ROUGE, this is implemented.
  srand($seed);
  for($i=0;$i<@{$instances};$i++) {
    # generate a random index
    $ridx=int(rand(@{$instances}));
    unless(defined($sample)) {
      # setup the resampling array
      $sample=[];
      push(@$sample,$scores->{$instances->[$ridx]}[0]);
      push(@$sample,$scores->{$instances->[$ridx]}[1]);
      push(@$sample,$scores->{$instances->[$ridx]}[2]);
    }
    else {
      # update the resampling array
      $sample->[0]+=$scores->{$instances->[$ridx]}[0];
      $sample->[1]+=$scores->{$instances->[$ridx]}[1];
      $sample->[2]+=$scores->{$instances->[$ridx]}[2];
    }
  }
  # compute the average result for this resampling procedure
  unless(defined($opt_t)) {
    # per instance or sentence average
    if(@{$instances}>0) {
      $sample->[0]/=@{$instances};
      $sample->[1]/=@{$instances};
      $sample->[2]/=@{$instances};
    }
    else {
      $sample->[0]=0;
      $sample->[1]=0;
      $sample->[2]=0;
    }
  }
  else {
    if($opt_t==1) {
      # per token or corpus level average
      # output recall, precision, and f-measure score
      my ($tmpR,$tmpP,$tmpF);
      if($sample->[0]>0) {
	$tmpR=$sample->[2]/$sample->[0]; # recall
      }
      else {
	$tmpR=0;
      }
      if($sample->[1]>0) {
	$tmpP=$sample->[2]/$sample->[1]; # precision
      }
      else {
	$tmpP=0;
      }
      if((1-$alpha)*$tmpP+$alpha*$tmpR>0) {
	$tmpF=($tmpR*$tmpP)/((1-$alpha)*$tmpP+$alpha*$tmpR); # f-measure
      }
      else {
	$tmpF=0;
      }
      $sample->[0]=$tmpR;
      $sample->[1]=$tmpP;
      $sample->[2]=$tmpF;
    }
    else {
      # $opt_t!=1 => output raw model token count, peer token count, and hit count
      # do nothing, just return $sample
    }
  }
  return $sample;
}

sub by_value {
  $a<=>$b;
}

sub printPerEvalData {
  my $ROUGEScores=shift;
  my $tag=shift; # tag to identify each evaluation
  my (@instances,$i,$j);
  
  @instances=sort by_evalID (keys %$ROUGEScores);
  foreach $i (@instances) {
    # print average per evaluation score
    print "$tag $i R:$ROUGEScores->{$i}[0] P:$ROUGEScores->{$i}[1] F:$ROUGEScores->{$i}[2]\n";
  }
}

sub by_evalID {
  my ($a1,$b1);

  if($a=~/^([0-9]+)/o) {
    $a1=$1;
  }
  if($b=~/^([0-9]+)/o) {
    $b1=$1;
  }
  if(defined($a1)&&defined($b1)) {
    return $a1<=>$b1;
  }
  else {
    return $a cmp $b;
  }
}

sub computeAverages {
  my $ROUGEScores=shift;
  my $ROUGEAverages=shift;
  my $opt_t=shift;
  my ($avgAvgROUGE_R,$resampleAvgROUGE_R);
  my ($avgAvgROUGE_P,$resampleAvgROUGE_P);
  my ($avgAvgROUGE_F,$resampleAvgROUGE_F);
  my ($ciU,$ciL);
  my (@instances,$i,$j,@rankedArray_R,@rankedArray_P,@RankedArray_F);
  
  @instances=sort (keys %$ROUGEScores);
  $avgAvgROUGE_R=0;
  $avgAvgROUGE_P=0;
  $avgAvgROUGE_F=0;
  $resampleAvgROUGE_R=0;
  $resampleAvgROUGE_P=0;
  $resampleAvgROUGE_F=0;
  # compute totals
  foreach $i (@instances) {
    $avgAvgROUGE_R+=$ROUGEScores->{$i}[0]; # recall     ; or model token count
    $avgAvgROUGE_P+=$ROUGEScores->{$i}[1]; # precision  ; or peer token count
    $avgAvgROUGE_F+=$ROUGEScores->{$i}[2]; # f1-measure ; or match token count (hit)
  }
  # compute averages
  unless(defined($opt_t)) {
    # per sentence average
    if((scalar @instances)>0) {
      $avgAvgROUGE_R=sprintf("%7.5f",$avgAvgROUGE_R/(scalar @instances));
      $avgAvgROUGE_P=sprintf("%7.5f",$avgAvgROUGE_P/(scalar @instances));
      $avgAvgROUGE_F=sprintf("%7.5f",$avgAvgROUGE_F/(scalar @instances));
    }
    else {
      $avgAvgROUGE_R=sprintf("%7.5f",0);
      $avgAvgROUGE_P=sprintf("%7.5f",0);
      $avgAvgROUGE_F=sprintf("%7.5f",0);
    }
  }
  else {
    if($opt_t==1) {
      # per token average on corpus level
      my ($tmpR,$tmpP,$tmpF);
      if($avgAvgROUGE_R>0) {
	$tmpR=$avgAvgROUGE_F/$avgAvgROUGE_R;
      }
      else {
	$tmpR=0;
      }
      if($avgAvgROUGE_P>0) {
	$tmpP=$avgAvgROUGE_F/$avgAvgROUGE_P;
      }
      else {
	$tmpP=0;
      }
      if((1-$alpha)*$tmpP+$alpha*$tmpR>0) {
	$tmpF=($tmpR+$tmpP)/((1-$alpha)*$tmpP+$alpha*$tmpR);
      }
      else {
	$tmpF=0;
      }
      $avgAvgROUGE_R=sprintf("%7.5f",$tmpR);
      $avgAvgROUGE_P=sprintf("%7.5f",$tmpP);
      $avgAvgROUGE_F=sprintf("%7.5f",$tmpF);
    }
  }
  if(!defined($opt_t)||$opt_t==1) {
    # compute confidence intervals using bootstrap resampling
    @ResamplingArray=();
    for($i=0;$i<$numOfResamples;$i++) {
      my $sample;
      
      $sample=&bootstrapResampling($ROUGEScores,\@instances,$i,$opt_t);
      # sample contains average sum of the sample
      if(@ResamplingArray==0) {
	# setup the resampling array for Avg
	my $s;
	
	$s=[];
	push(@$s,$sample->[0]);
	push(@ResamplingArray,$s);
	$s=[];
	push(@$s,$sample->[1]);
	push(@ResamplingArray,$s);
	$s=[];
	push(@$s,$sample->[2]);
	push(@ResamplingArray,$s);
      }
      else {
	$rsa=$ResamplingArray[0];
	push(@{$rsa},$sample->[0]);
	$rsa=$ResamplingArray[1];
	push(@{$rsa},$sample->[1]);
	$rsa=$ResamplingArray[2];
	push(@{$rsa},$sample->[2]);
      }
    }
    # sort resampling results
    {
      # recall
      @rankedArray_R=sort by_value (@{$ResamplingArray[0]});
      $ResamplingArray[0]=\@rankedArray_R;
      for($x=0;$x<=$#rankedArray_R;$x++) {
	$resampleAvgROUGE_R+=$rankedArray_R[$x];
	#	print "*R ($x): $rankedArray_R[$x]\n";
      }
      $resampleAvgROUGE_R=sprintf("%7.5f",$resampleAvgROUGE_R/(scalar @rankedArray_R));
      # precision
      @rankedArray_P=sort by_value (@{$ResamplingArray[1]});
      $ResamplingArray[1]=\@rankedArray_P;
      for($x=0;$x<=$#rankedArray_P;$x++) {
	$resampleAvgROUGE_P+=$rankedArray_P[$x];
	#	print "*P ($x): $rankedArray_P[$x]\n";
      }
      $resampleAvgROUGE_P=sprintf("%7.5f",$resampleAvgROUGE_P/(scalar @rankedArray_P));
      # f1-measure
      @rankedArray_F=sort by_value (@{$ResamplingArray[2]});
      $ResamplingArray[2]=\@rankedArray_F;
      for($x=0;$x<=$#rankedArray_F;$x++) {
	$resampleAvgROUGE_F+=$rankedArray_F[$x];
	#	print "*F ($x): $rankedArray_F[$x]\n";
      }
      $resampleAvgROUGE_F=sprintf("%7.5f",$resampleAvgROUGE_F/(scalar @rankedArray_F));
    }
    #    $ciU=999-int((100-$opt_c)*10/2); # upper bound index
    #    $ciL=int((100-$opt_c)*10/2);     # lower bound index
    $delta=$numOfResamples*((100-$opt_c)/2.0)/100.0;
    $ciUa=int($numOfResamples-$delta-1); # upper confidence interval lower index
    $ciUb=$ciUa+1;                       # upper confidence interval upper index
    $ciLa=int($delta);                   # lower confidence interval lower index
    $ciLb=$ciLa+1;                       # lower confidence interval upper index
    $ciR=$numOfResamples-$delta-1-$ciUa; # ratio bewteen lower and upper indexes
    #    $ROUGEAverages->{"AvgR"}=$avgAvgROUGE_R;
    #-------
    # recall
    $ROUGEAverages->{"AvgR"}=$resampleAvgROUGE_R;
    # find condifence intervals; take maximum distance from the mean
    $ROUGEAverages->{"CIAvgL_R"}=sprintf("%7.5f",$ResamplingArray[0][$ciLa]+
					 ($ResamplingArray[0][$ciLb]-$ResamplingArray[0][$ciLa])*$ciR);
    $ROUGEAverages->{"CIAvgU_R"}=sprintf("%7.5f",$ResamplingArray[0][$ciUa]+
					 ($ResamplingArray[0][$ciUb]-$ResamplingArray[0][$ciUa])*$ciR);
    #-------
    # precision
    $ROUGEAverages->{"AvgP"}=$resampleAvgROUGE_P;
    # find condifence intervals; take maximum distance from the mean
    $ROUGEAverages->{"CIAvgL_P"}=sprintf("%7.5f",$ResamplingArray[1][$ciLa]+
					 ($ResamplingArray[1][$ciLb]-$ResamplingArray[1][$ciLa])*$ciR);
    $ROUGEAverages->{"CIAvgU_P"}=sprintf("%7.5f",$ResamplingArray[1][$ciUa]+
					 ($ResamplingArray[1][$ciUb]-$ResamplingArray[1][$ciUa])*$ciR);
    #-------
    # f1-measure
    $ROUGEAverages->{"AvgF"}=$resampleAvgROUGE_F;
    # find condifence intervals; take maximum distance from the mean
    $ROUGEAverages->{"CIAvgL_F"}=sprintf("%7.5f",$ResamplingArray[2][$ciLa]+
					 ($ResamplingArray[2][$ciLb]-$ResamplingArray[2][$ciLa])*$ciR);
    $ROUGEAverages->{"CIAvgU_F"}=sprintf("%7.5f",$ResamplingArray[2][$ciUa]+
					 ($ResamplingArray[2][$ciUb]-$ResamplingArray[2][$ciUa])*$ciR);
    $ROUGEAverages->{"M_cnt"}=$avgAvgROUGE_R; # model token count
    $ROUGEAverages->{"P_cnt"}=$avgAvgROUGE_P; # peer token count
    $ROUGEAverages->{"H_cnt"}=$avgAvgROUGE_F; # hit token count
  }
  else {
    # $opt_t==2 => output raw count instead of precision, recall, and f-measure values
    # in this option, no resampling is necessary, just output the raw counts
    $ROUGEAverages->{"M_cnt"}=$avgAvgROUGE_R; # model token count
    $ROUGEAverages->{"P_cnt"}=$avgAvgROUGE_P; # peer token count
    $ROUGEAverages->{"H_cnt"}=$avgAvgROUGE_F; # hit token count
  }
}

sub computeROUGEX {
  my $metric=shift;       # which ROUGE metric to compute?
  my $ROUGEScores=shift;
  my $evalID=shift;
  my $ROUGEEval=shift;    # one particular evaluation pair
  my $peerID=shift;       # a specific peer ID
  my $ROUGEParam=shift;   # ROUGE scoring parameters
  my $lengthLimit;        # lenght limit in words
  my $byteLimit;          # length limit in bytes
  my $NSIZE;              # ngram size for ROUGE-N
  my $weightFactor;       # weight factor for ROUGE-W
  my $skipDistance;       # skip distance for ROUGE-S
  my $scoreMode;          # scoring mode: A = model average; B = best model
  my $alpha;              # relative importance between recall and precision
  my $opt_t;              # ROUGE score counting mode
  my $BEMode;             # Basic Element scoring mode
  my ($c,$cx,@modelPaths,$modelIDs,$modelRoot,$inputFormat);

  $lengthLimit=$ROUGEParam->{"LENGTH"};
  $byteLimit=$ROUGEParam->{"BYTE"};
  $NSIZE=$ROUGEParam->{"NSIZE"};
  $weightFactor=$ROUGEParam->{"WEIGHT"};
  $skipDistance=$ROUGEParam->{"SD"};
  $scoreMode=$ROUGEParam->{"SM"};
  $alpha=$ROUGEParam->{"ALPHA"};
  $opt_t=$ROUGEParam->{"AVERAGE"};
  $BEMode=$ROUGEParam->{"BEMODE"};
  
  # Check to see if this evaluation trial contains this $peerID.
  # Sometimes not every peer provides response for each
  # evaluation trial.
  unless(exists($ROUGEEval->{"Ps"}{$peerID})) {
    unless(exists($knownMissing{$evalID})) {
      $knownMissing{$evalID}={};
    }
    unless(exists($knownMissing{$evalID}{$peerID})) {
      print STDERR "\*ROUGE Warning: test instance for peer $peerID does not exist for evaluation $evalID\n";
      $knownMissing{$evalID}{$peerID}=1;
    }
    return;
  }
  unless(defined($opt_z)) {
    $peerPath=$ROUGEEval->{"PR"}."/".$ROUGEEval->{"Ps"}{$peerID};
  }
  else {
    # if opt_z is set then peerPath is read from a file list that
    # includes the path to the peer.
    $peerPath=$ROUGEEval->{"Ps"}{$peerID};
  }
  if(defined($ROUGEEval->{"MR"})) {
    $modelRoot=$ROUGEEval->{"MR"};
  }
  else {
    # if opt_z is set then modelPath is read from a file list that
    # includes the path to the model.
    $modelRoot="";
  }
  $modelIDs=$ROUGEEval->{"MIDList"};
  $inputFormat=$ROUGEEval->{"IF"};
  # construct combined model
  @modelPaths=(); # reset model paths
  for($cx=0;$cx<=$#{$modelIDs};$cx++) {
    my $modelID;
    $modelID=$modelIDs->[$cx];
    unless(defined($opt_z)) {
      $modelPath="$modelRoot/$ROUGEEval->{\"Ms\"}{$modelID}"; # get full model path
    }
    else {
      # if opt_z is set then modelPath is read from a file list that
      # includes the full path to the model.
      $modelPath="$ROUGEEval->{\"Ms\"}{$modelID}"; # get full model path
    }
    if(-e "$modelPath") {
      #		    print "*$modelPath\n";
    }
    else {
      die "Cannot find model summary: $modelPath\n";
    }
    push(@modelPaths,$modelPath);
  }
  #---------------------------------------------------------------
  # evaluate peer
  {
    my (@results);
    my ($testID,$avgROUGE,$avgROUGE_P,$avgROUGE_F);
    @results=();
    if($metric eq "N") {
      &computeNGramScore(\@modelPaths,$peerPath,\@results,$NSIZE,$lengthLimit,$byteLimit,$inputFormat,$scoreMode,$alpha);
    }
    elsif($metric eq "L") {
      &computeLCSScore(\@modelPaths,$peerPath,\@results,$lengthLimit,$byteLimit,$inputFormat,$scoreMode,$alpha);
    }
    elsif($metric eq "W") {
      &computeWLCSScore(\@modelPaths,$peerPath,\@results,$lengthLimit,$byteLimit,$inputFormat,$weightFactor,$scoreMode,$alpha);
    }
    elsif($metric eq "S") {
      &computeSkipBigramScore(\@modelPaths,$peerPath,\@results,$skipDistance,$lengthLimit,$byteLimit,$inputFormat,$scoreMode,$alpha);
    }
    elsif($metric eq "BE") {
      &computeBEScore(\@modelPaths,$peerPath,\@results,$BEMode,$lengthLimit,$byteLimit,$inputFormat,$scoreMode,$alpha);
    }
    else {
      die "Unknown ROUGE metric ID: $metric, has to be N, L, W, or S\n";
      
    }
    unless(defined($opt_t)) {
      # sentence level average
      $avgROUGE=sprintf("%7.5f",$results[2]);
      $avgROUGE_P=sprintf("%7.5f",$results[4]);
      $avgROUGE_F=sprintf("%7.5f",$results[5]);
    }
    else {
      # corpus level per token average
      $avgROUGE=$results[0]; # total model token count
      $avgROUGE_P=$results[3]; # total peer token count
      $avgROUGE_F=$results[1]; # total match count between model and peer, i.e. hit
    }
    # record ROUGE scores for the current test
    $testID="$evalID\.$peerID";
    if($debug) {
      print "$testID\n";
    }
    unless(exists($testIDs{$testID})) {
      $testIDs{$testID}=1;
    }
    unless(exists($ROUGEScores->{$testID})) {
      $ROUGEScores->{$testID}=[];
      push(@{$ROUGEScores->{$testID}},$avgROUGE);   # average ; or model token count
      push(@{$ROUGEScores->{$testID}},$avgROUGE_P); # average ; or peer token count
      push(@{$ROUGEScores->{$testID}},$avgROUGE_F); # average ; or match token count (hit)
    }
  }
}

# 10/21/2004 add selection of scoring mode
# A: average over all models
# B: take only the best score
sub computeNGramScore {
  my $modelPaths=shift;
  my $peerPath=shift;
  my $results=shift;
  my $NSIZE=shift;
  my $lengthLimit=shift;
  my $byteLimit=shift;
  my $inputFormat=shift;
  my $scoreMode=shift;
  my $alpha=shift;
  my ($modelPath,$modelText,$peerText,$text,@tokens);
  my (%model_grams,%peer_grams);
  my ($gramHit,$gramScore,$gramScoreBest);
  my ($totalGramHit,$totalGramCount);
  my ($gramScoreP,$gramScoreF,$totalGramCountP);
  
  #------------------------------------------------
  # read model file and create model n-gram maps
  $totalGramHit=0;
  $totalGramCount=0;
  $gramScoreBest=-1;
  $gramScoreP=0; # precision
  $gramScoreF=0; # f-measure
  $totalGramCountP=0;
  #------------------------------------------------
  # read peer file and create model n-gram maps
  %peer_grams=();
  $peerText="";
  &readText($peerPath,\$peerText,$inputFormat,$lengthLimit,$byteLimit);
  &createNGram($peerText,\%peer_grams,$NSIZE);
  if($debug) {
    print "***P $peerPath\n";
    if(defined($peerText)) {
      print "$peerText\n";
      print join("|",%peer_grams),"\n";
    }
    else {
      print "---empty text---\n";
    }
  }
  foreach $modelPath (@$modelPaths) {
    %model_grams=();
    $modelText="";
    &readText($modelPath,\$modelText,$inputFormat,$lengthLimit,$byteLimit);
    &createNGram($modelText,\%model_grams,$NSIZE);
    if($debug) {
      if(defined($modelText)) {
	print "$modelText\n";
	print join("|",%model_grams),"\n";
      }
      else {
	print "---empty text---\n";
      }
    }
    #------------------------------------------------
    # EDIT-WE
    # compute ngram score
    ngramWord2VecScore(\%model_grams,\%peer_grams,\$gramHit,\$gramScore);
    #&ngramScore(\%model_grams,\%peer_grams,\$gramHit,\$gramScore);
    # collect hit and count for each models
    # This will effectively clip hit for each model; therefore would not give extra
    # credit to reducdant information contained in the peer summary.
    if($scoreMode eq "A") {
      $totalGramHit+=$gramHit;
      $totalGramCount+=$model_grams{"_cn_"};
      $totalGramCountP+=$peer_grams{"_cn_"};
    }
    elsif($scoreMode eq "B") {
      if($gramScore>$gramScoreBest) {
	# only take a better score (i.e. better match)
	$gramScoreBest=$gramScore;
	$totalGramHit=$gramHit;
	$totalGramCount=$model_grams{"_cn_"};
	$totalGramCountP=$peer_grams{"_cn_"};
      }
    }
    else {
      # use average mode
      $totalGramHit+=$gramHit;
      $totalGramCount+=$model_grams{"_cn_"};
      $totalGramCountP+=$peer_grams{"_cn_"};
    }
    if($debug) {
      print "***M $modelPath\n";
    }
  }
  # prepare score result for return
  # unigram
  push(@$results,$totalGramCount); # total number of ngrams in models
  push(@$results,$totalGramHit);
  if($totalGramCount!=0) {
    $gramScore=sprintf("%7.5f",$totalGramHit/$totalGramCount);
  }
  else {
    $gramScore=sprintf("%7.5f",0);
  }
  push(@$results,$gramScore);
  push(@$results,$totalGramCountP); # total number of ngrams in peers
  if($totalGramCountP!=0) {
    $gramScoreP=sprintf("%7.5f",$totalGramHit/$totalGramCountP);
  }
  else {
    $gramScoreP=sprintf("%7.5f",0);
  }
  push(@$results,$gramScoreP);      # precision score
  if((1-$alpha)*$gramScoreP+$alpha*$gramScore>0) {
    $gramScoreF=sprintf("%7.5f",($gramScoreP*$gramScore)/((1-$alpha)*$gramScoreP+$alpha*$gramScore));
  }
  else {
    $gramScoreF=sprintf("%7.5f",0);
  }
  push(@$results,$gramScoreF);      # f1-measure score
  if($debug) {
    print "total $NSIZE-gram model count: $totalGramCount\n";
    print "total $NSIZE-gram peer count: $totalGramCountP\n";
    print "total $NSIZE-gram hit: $totalGramHit\n";
    print "total ROUGE-$NSIZE\-R: $gramScore\n";
    print "total ROUGE-$NSIZE\-P: $gramScoreP\n";
    print "total ROUGE-$NSIZE\-F: $gramScoreF\n";
  }
}

sub computeSkipBigramScore {
  my $modelPaths=shift;
  my $peerPath=shift;
  my $results=shift;
  my $skipDistance=shift;
  my $lengthLimit=shift;
  my $byteLimit=shift;
  my $inputFormat=shift;
  my $scoreMode=shift;
  my $alpha=shift;
  my ($modelPath,$modelText,$peerText,$text,@tokens);
  my (%model_grams,%peer_grams);
  my ($gramHit,$gramScore,$gramScoreBest);
  my ($totalGramHitm,$totalGramCount);
  my ($gramScoreP,$gramScoreF,$totalGramCountP);
  
  #------------------------------------------------
  # read model file and create model n-gram maps
  $totalGramHit=0;
  $totalGramCount=0;
  $gramScoreBest=-1;
  $gramScoreP=0; # precision
  $gramScoreF=0; # f-measure
  $totalGramCountP=0;
  #------------------------------------------------
  # read peer file and create model n-gram maps
  %peer_grams=();
  $peerText="";
  &readText($peerPath,\$peerText,$inputFormat,$lengthLimit,$byteLimit);
  &createSkipBigram($peerText,\%peer_grams,$skipDistance);
  if($debug) {
    print "***P $peerPath\n";
    if(defined($peerText)) {
      print "$peerText\n";
      print join("|",%peer_grams),"\n";
    }
    else {
      print "---empty text---\n";
    }
  }
  foreach $modelPath (@$modelPaths) {
    %model_grams=();
    $modelText="";
    &readText($modelPath,\$modelText,$inputFormat,$lengthLimit,$byteLimit);
    if(defined($opt_M)) { # only apply stemming on models
      $opt_m=1;
    }
    &createSkipBigram($modelText,\%model_grams,$skipDistance);
    if(defined($opt_M)) { # only apply stemming on models
      $opt_m=undef;
    }
    if($debug) {
      if(defined($modelText)) {
	print "$modelText\n";
	print join("|",%model_grams),"\n";
      }
      else {
	print "---empty text---\n";
      }
    }
    #------------------------------------------------
    # compute ngram score
    ### EDIT-WE Re-factor - skipBigramScore is the same function as ngramScore
    ###  To compute ROUGE-WE-SUX, we can thus replace this call to ngramWord2VecScore
    &ngramWord2VecScore(\%model_grams,\%peer_grams,\$gramHit,\$gramScore);
    ###&skipBigramScore(\%model_grams,\%peer_grams,\$gramHit,\$gramScore);
    # collect hit and count for each models
    # This will effectively clip hit for each model; therefore would not give extra
    # credit to reducdant information contained in the peer summary.
    if($scoreMode eq "A") {
      $totalGramHit+=$gramHit;
      $totalGramCount+=$model_grams{"_cn_"};
      $totalGramCountP+=$peer_grams{"_cn_"};
    }
    elsif($scoreMode eq "B") {
      if($gramScore>$gramScoreBest) {
	# only take a better score (i.e. better match)
	$gramScoreBest=$gramScore;
	$totalGramHit=$gramHit;
	$totalGramCount=$model_grams{"_cn_"};
	$totalGramCountP=$peer_grams{"_cn_"};
      }
    }
    else {
      # use average mode
      $totalGramHit+=$gramHit;
      $totalGramCount+=$model_grams{"_cn_"};
      $totalGramCountP+=$peer_grams{"_cn_"};
    }
    if($debug) {
      print "***M $modelPath\n";
    }
  }
  # prepare score result for return
  # unigram
  push(@$results,$totalGramCount); # total number of ngrams
  push(@$results,$totalGramHit);
  if($totalGramCount!=0) {
    $gramScore=sprintf("%7.5f",$totalGramHit/$totalGramCount);
  }
  else {
    $gramScore=sprintf("%7.5f",0);
  }
  push(@$results,$gramScore);
  push(@$results,$totalGramCountP); # total number of ngrams in peers
  if($totalGramCountP!=0) {
    $gramScoreP=sprintf("%7.5f",$totalGramHit/$totalGramCountP);
  }
  else {
    $gramScoreP=sprintf("%7.5f",0);
  }
  push(@$results,$gramScoreP);      # precision score
  if((1-$alpha)*$gramScoreP+$alpha*$gramScore>0) {
    $gramScoreF=sprintf("%7.5f",($gramScoreP*$gramScore)/((1-$alpha)*$gramScoreP+$alpha*$gramScore));
  }
  else {
    $gramScoreF=sprintf("%7.5f",0);
  }
  push(@$results,$gramScoreF);      # f1-measure score
  if($debug) {
    print "total ROUGE-S$skipDistance model count: $totalGramCount\n";
    print "total ROUGE-S$skipDistance peer count: $totalGramCountP\n";
    print "total ROUGE-S$skipDistance hit: $totalGramHit\n";
    print "total ROUGE-S$skipDistance\-R: $gramScore\n";
    print "total ROUGE-S$skipDistance\-P: $gramScore\n";
    print "total ROUGE-S$skipDistance\-F: $gramScore\n";
  }
}

sub computeLCSScore {
  my $modelPaths=shift;
  my $peerPath=shift;
  my $results=shift;
  my $lengthLimit=shift;
  my $byteLimit=shift;
  my $inputFormat=shift;
  my $scoreMode=shift;
  my $alpha=shift;
  my ($modelPath,@modelText,@peerText,$text,@tokens);
  my (@modelTokens,@peerTokens);
  my ($lcsHit,$lcsScore,$lcsBase,$lcsScoreBest);
  my ($totalLCSHitm,$totalLCSCount);
  my (%peer_1grams,%tmp_peer_1grams,%model_1grams,$peerText1,$modelText1);
  my ($lcsScoreP,$lcsScoreF,$totalLCSCountP);
  
  #------------------------------------------------
  $totalLCSHit=0;
  $totalLCSCount=0;
  $lcsScoreBest=-1;
  $lcsScoreP=0;
  $lcsScoreF=0;
  $totalLCSCountP=0;
  #------------------------------------------------
  # read peer file and create peer n-gram maps
  @peerTokens=();
  @peerText=();
  &readText_LCS($peerPath,\@peerText,$inputFormat,$lengthLimit,$byteLimit);
  &tokenizeText_LCS(\@peerText,\@peerTokens);
  #------------------------------------------------
  # create unigram for clipping
  %peer_1grams=();
  &readText($peerPath,\$peerText1,$inputFormat,$lengthLimit,$byteLimit);
  &createNGram($peerText1,\%peer_1grams,1);
  if($debug) {
    my $i;
    print "***P $peerPath\n";
    print join("\n",@peerText),"\n";
    for($i=0;$i<=$#peerText;$i++) {
      print $i,": ",join("|",@{$peerTokens[$i]}),"\n";
    }
  }
  foreach $modelPath (@$modelPaths) {
    %tmp_peer_1grams=%peer_1grams; # renew peer unigram hash, so the peer count can be reset to the orignal number
    @modelTokens=();
    @modelText=();
    &readText_LCS($modelPath,\@modelText,$inputFormat,$lengthLimit,$byteLimit);
    if(defined($opt_M)) {
      $opt_m=1;
      &tokenizeText_LCS(\@modelText,\@modelTokens);
      $opt_m=undef;
    }
    else {
      &tokenizeText_LCS(\@modelText,\@modelTokens);
    }
    #------------------------------------------------
    # create unigram for clipping
    %model_1grams=();
    &readText($modelPath,\$modelText1,$inputFormat,$lengthLimit,$byteLimit);
    if(defined($opt_M)) { # only apply stemming on models
      $opt_m=1;
    }        
    &createNGram($modelText1,\%model_1grams,1);
    if(defined($opt_M)) { # only apply stemming on models
      $opt_m=undef;
    }
    #------------------------------------------------
    # compute LCS score
    &lcs(\@modelTokens,\@peerTokens,\$lcsHit,\$lcsScore,\$lcsBase,\%model_1grams,\%tmp_peer_1grams);
    # collect hit and count for each models
    # This will effectively clip hit for each model; therefore would not give extra
    # credit to reductant information contained in the peer summary.
    # Previous method that lumps model text together and inflates the peer summary
    # the number of references time would reward redundant information
    if($scoreMode eq "A") {
      $totalLCSHit+=$lcsHit;
      $totalLCSCount+=$lcsBase;
      $totalLCSCountP+=$peer_1grams{"_cn_"};
    }
    elsif($scoreMode eq "B") {
      if($lcsScore>$lcsScoreBest) {
	# only take a better score (i.e. better match)
	$lcsScoreBest=$lcsScore;
	$totalLCSHit=$lcsHit;
	$totalLCSCount=$lcsBase;
	$totalLCSCountP=$peer_1grams{"_cn_"};
      }
    }
    else {
      # use average mode
      $totalLCSHit+=$lcsHit;
      $totalLCSCount+=$lcsBase;
      $totalLCSCountP+=$peer_1grams{"_cn_"};
    }
    if($debug) {
      my $i;
      print "***M $modelPath\n";
      print join("\n",@modelText),"\n";
      for($i=0;$i<=$#modelText;$i++) {
	print $i,": ",join("|",@{$modelTokens[$i]}),"\n";
      }
    }
  }
  # prepare score result for return
  push(@$results,$totalLCSCount); # total number of ngrams
  push(@$results,$totalLCSHit);
  if($totalLCSCount!=0) {
    $lcsScore=sprintf("%7.5f",$totalLCSHit/$totalLCSCount);
  }
  else {
    $lcsScore=sprintf("%7.5f",0);
  }
  push(@$results,$lcsScore);
  push(@$results,$totalLCSCountP); # total number of token in peers
  if($totalLCSCountP!=0) {
    $lcsScoreP=sprintf("%7.5f",$totalLCSHit/$totalLCSCountP);
  }
  else {
    $lcsScoreP=sprintf("%7.5f",0);
  }
  push(@$results,$lcsScoreP);
  if((1-$alpha)*$lcsScoreP+$alpha*$lcsScore>0) {
    $lcsScoreF=sprintf("%7.5f",($lcsScoreP*$lcsScore)/((1-$alpha)*$lcsScoreP+$alpha*$lcsScore));
  }
  else {
    $lcsScoreF=sprintf("%7.5f",0);
  }
  push(@$results,$lcsScoreF);
  if($debug) {
    print "total ROUGE-L model count: $totalLCSCount\n";
    print "total ROUGE-L peer count: $totalLCSCountP\n";
    print "total ROUGE-L hit: $totalLCSHit\n";
    print "total ROUGE-L-R score: $lcsScore\n";
    print "total ROUGE-L-P: $lcsScoreP\n";
    print "total ROUGE-L-F: $lcsScoreF\n";
  }
}

sub computeWLCSScore {
  my $modelPaths=shift;
  my $peerPath=shift;
  my $results=shift;
  my $lengthLimit=shift;
  my $byteLimit=shift;
  my $inputFormat=shift;
  my $weightFactor=shift;
  my $scoreMode=shift;
  my $alpha=shift;
  my ($modelPath,@modelText,@peerText,$text,@tokens);
  my (@modelTokens,@peerTokens);
  my ($lcsHit,$lcsScore,$lcsBase,$lcsScoreBest);
  my ($totalLCSHitm,$totalLCSCount);
  my (%peer_1grams,%tmp_peer_1grams,%model_1grams,$peerText1,$modelText1);
  my ($lcsScoreP,$lcsScoreF,$totalLCSCountP);
  
  #------------------------------------------------
  # read model file and create model n-gram maps
  $totalLCSHit=0;
  $totalLCSCount=0;
  $lcsScoreBest=-1;
  $lcsScoreP=0;
  $lcsScoreF=0;
  $totalLCSCountP=0;
  #------------------------------------------------
  # read peer file and create model n-gram maps
  @peerTokens=();
  @peerText=();
  &readText_LCS($peerPath,\@peerText,$inputFormat,$lengthLimit,$byteLimit);
  &tokenizeText_LCS(\@peerText,\@peerTokens);
  #------------------------------------------------
  # create unigram for clipping
  %peer_1grams=();
  &readText($peerPath,\$peerText1,$inputFormat,$lengthLimit,$byteLimit);
  &createNGram($peerText1,\%peer_1grams,1);
  if($debug) {
    my $i;
    print "***P $peerPath\n";
    print join("\n",@peerText),"\n";
    for($i=0;$i<=$#peerText;$i++) {
      print $i,": ",join("|",@{$peerTokens[$i]}),"\n";
    }
  }
  foreach $modelPath (@$modelPaths) {
    %tmp_peer_1grams=%peer_1grams; # renew peer unigram hash, so the peer count can be reset to the orignal number
    @modelTokens=();
    @modelText=();
    &readText_LCS($modelPath,\@modelText,$inputFormat,$lengthLimit,$byteLimit);
    &tokenizeText_LCS(\@modelText,\@modelTokens);
    #------------------------------------------------
    # create unigram for clipping
    %model_1grams=();
    &readText($modelPath,\$modelText1,$inputFormat,$lengthLimit,$byteLimit);
    if(defined($opt_M)) { # only apply stemming on models
      $opt_m=1;
    }
    &createNGram($modelText1,\%model_1grams,1);
    if(defined($opt_M)) { # only apply stemming on models
      $opt_m=undef;
    }
    #------------------------------------------------
    # compute WLCS score
    &wlcs(\@modelTokens,\@peerTokens,\$lcsHit,\$lcsScore,\$lcsBase,$weightFactor,\%model_1grams,\%tmp_peer_1grams);
    # collect hit and count for each models
    # This will effectively clip hit for each model; therefore would not give extra
    # credit to reductant information contained in the peer summary.
    # Previous method that lumps model text together and inflates the peer summary
    # the number of references time would reward redundant information
    if($scoreMode eq "A") {
      $totalLCSHit+=$lcsHit;
      $totalLCSCount+=&wlcsWeight($lcsBase,$weightFactor);
      $totalLCSCountP+=&wlcsWeight($peer_1grams{"_cn_"},$weightFactor);
    }
    elsif($scoreMode eq "B") {
      if($lcsScore>$lcsScoreBest) {
	# only take a better score (i.e. better match)
	$lcsScoreBest=$lcsScore;
	$totalLCSHit=$lcsHit;
	$totalLCSCount=&wlcsWeight($lcsBase,$weightFactor);
	$totalLCSCountP=&wlcsWeight($peer_1grams{"_cn_"},$weightFactor);
      }
    }
    else {
      # use average mode
      $totalLCSHit+=$lcsHit;
      $totalLCSCount+=&wlcsWeight($lcsBase,$weightFactor);
      $totalLCSCountP+=&wlcsWeight($peer_1grams{"_cn_"},$weightFactor);
    }
    if($debug) {
      my $i;
      print "***M $modelPath\n";
      print join("\n",@modelText),"\n";
      for($i=0;$i<=$#modelText;$i++) {
	print $i,": ",join("|",@{$modelTokens[$i]}),"\n";
      }
    }
  }
  # prepare score result for return
  push(@$results,$totalLCSCount); # total number of ngrams
  push(@$results,$totalLCSHit);
  if($totalLCSCount!=0) {
    $lcsScore=sprintf("%7.5f",&wlcsWeightInverse($totalLCSHit/$totalLCSCount,$weightFactor));
  }
  else {
    $lcsScore=sprintf("%7.5f",0);
  }
  push(@$results,$lcsScore);
  push(@$results,$totalLCSCountP); # total number of token in peers
  if($totalLCSCountP!=0) {
    $lcsScoreP=sprintf("%7.5f",&wlcsWeightInverse($totalLCSHit/$totalLCSCountP,$weightFactor));
  }
  else {
    $lcsScoreP=sprintf("%7.5f",0);
  }
  push(@$results,$lcsScoreP);
  if((1-$alpha)*$lcsScoreP+$alpha*$lcsScore>0) {
    $lcsScoreF=sprintf("%7.5f",($lcsScoreP*$lcsScore)/((1-$alpha)*$lcsScoreP+$alpha*$lcsScore));
  }
  else {
    $lcsScoreF=sprintf("%7.5f",0);
  }
  push(@$results,$lcsScoreF);
  if($debug) {
    print "total ROUGE-W-$weightFactor model count: $totalLCSCount\n";
    print "total ROUGE-W-$weightFactor peer count: $totalLCSCountP\n";
    print "total ROUGE-W-$weightFactor hit: $totalLCSHit\n";
    print "total ROUGE-W-$weightFactor-R score: $lcsScore\n";
    print "total ROUGE-W-$weightFactor-P score: $lcsScoreP\n";
    print "total ROUGE-W-$weightFactor-F score: $lcsScoreF\n";
  }
}

sub computeBEScore {
  my $modelPaths=shift;
  my $peerPath=shift;
  my $results=shift;
  my $BEMode=shift;
  my $lengthLimit=shift;
  my $byteLimit=shift;
  my $inputFormat=shift;
  my $scoreMode=shift;
  my $alpha=shift;
  my ($modelPath,@modelBEList,@peerBEList,$text,@tokens);
  my (%model_BEs,%peer_BEs);
  my ($BEHit,$BEScore,$BEScoreBest);
  my ($totalBEHit,$totalBECount);
  my ($BEScoreP,$BEScoreF,$totalBECountP);
  
  #------------------------------------------------
  # read model file and create model BE maps
  $totalBEHit=0;
  $totalBECount=0;
  $BEScoreBest=-1;
  $BEScoreP=0; # precision
  $BEScoreF=0; # f-measure
  $totalBECountP=0;
  #------------------------------------------------
  # read peer file and create model n-BE maps
  %peer_BEs=();
  @peerBEList=();
  &readBE($peerPath,\@peerBEList,$inputFormat);
  &createBE(\@peerBEList,\%peer_BEs,$BEMode);
  if($debug) {
    print "***P $peerPath\n";
    if(scalar @peerBEList > 0) {
#      print join("\n",@peerBEList);
#      print "\n";
      print join("#",%peer_BEs),"\n";
    }
    else {
      print "---empty text---\n";
    }
  }
  foreach $modelPath (@$modelPaths) {
    %model_BEs=();
    @modelBEList=();
    &readBE($modelPath,\@modelBEList,$inputFormat);
    if(defined($opt_M)) { # only apply stemming on models
      $opt_m=1;
    }
    &createBE(\@modelBEList,\%model_BEs,$BEMode);
    if(defined($opt_M)) { # only apply stemming on models
      $opt_m=undef;
    }
    if($debug) {
      if(scalar @modelBEList > 0) {
#	print join("\n",@modelBEList);
#	print "\n";
	print join("#",%model_BEs),"\n";
      }
      else {
	print "---empty text---\n";
      }
    }
    #------------------------------------------------
    # compute BE score
    &getBEScore(\%model_BEs,\%peer_BEs,\$BEHit,\$BEScore);
    # collect hit and count for each models
    # This will effectively clip hit for each model; therefore would not give extra
    # credit to reducdant information contained in the peer summary.
    if($scoreMode eq "A") {
      $totalBEHit+=$BEHit;
      $totalBECount+=$model_BEs{"_cn_"};
      $totalBECountP+=$peer_BEs{"_cn_"};
    }
    elsif($scoreMode eq "B") {
      if($BEScore>$BEScoreBest) {
	# only take a better score (i.e. better match)
	$BEScoreBest=$BEScore;
	$totalBEHit=$BEHit;
	$totalBECount=$model_BEs{"_cn_"};
	$totalBECountP=$peer_BEs{"_cn_"};
      }
    }
    else {
      # use average mode
      $totalBEHit+=$BEHit;
      $totalBECount+=$model_BEs{"_cn_"};
      $totalBECountP+=$peer_BEs{"_cn_"};
    }
    if($debug) {
      print "***M $modelPath\n";
    }
  }
  # prepare score result for return
  # uniBE
  push(@$results,$totalBECount); # total number of nbes in models
  push(@$results,$totalBEHit);
  if($totalBECount!=0) {
    $BEScore=sprintf("%7.5f",$totalBEHit/$totalBECount);
  }
  else {
    $BEScore=sprintf("%7.5f",0);
  }
  push(@$results,$BEScore);
  push(@$results,$totalBECountP); # total number of nBEs in peers
  if($totalBECountP!=0) {
    $BEScoreP=sprintf("%7.5f",$totalBEHit/$totalBECountP);
  }
  else {
    $BEScoreP=sprintf("%7.5f",0);
  }
  push(@$results,$BEScoreP);      # precision score
  if((1-$alpha)*$BEScoreP+$alpha*$BEScore>0) {
    $BEScoreF=sprintf("%7.5f",($BEScoreP*$BEScore)/((1-$alpha)*$BEScoreP+$alpha*$BEScore));
  }
  else {
    $BEScoreF=sprintf("%7.5f",0);
  }
  push(@$results,$BEScoreF);      # f1-measure score
  if($debug) {
    print "total BE-$BEMode model count: $totalBECount\n";
    print "total BE-$BEMode peer count: $totalBECountP\n";
    print "total BE-$BEMode hit: $totalBEHit\n";
    print "total ROUGE-BE-$BEMode\-R: $BEScore\n";
    print "total ROUGE-BE-$BEMode\-P: $BEScoreP\n";
    print "total ROUGE-BE-$BEMode\-F: $BEScoreF\n";
  }
}

sub readTextOld {
  my $inPath=shift;
  my $tokenizedText=shift;
  my $type=shift;
  my $lengthLimit=shift;
  my $byteLimit=shift;
  my ($text,$bsize,$wsize,@words,$done);
  
  $$tokenizedText=undef;
  $bsize=0;
  $wsize=0;
  $done=0;
  open(TEXT,$inPath)||die "Cannot open $inPath\n";
  if($type=~/^SEE$/oi) {
    while(defined($line=<TEXT>)) { # SEE abstract format
      if($line=~/^<a (size=\"[0-9]+\" )?name=\"[0-9]+\">\[([0-9]+)\]<\/a>\s+<a href=\"\#[0-9]+\" id=[0-9]+>([^<]+)/o) {
	$text=$3;
	$text=~tr/A-Z/a-z/;
	&checkSummarySize($tokenizedText,\$text,\$wsize,\$bsize,\$done,$lengthLimit,$byteLimit);
      }
    }
  }
  elsif($type=~/^ISI$/oi) { # ISI standard sentence by sentence format
    while(defined($line=<TEXT>)) {
      if($line=~/^<S SNTNO=\"[0-9a-z,]+\">([^<]+)<\/S>/o) {
	$text=$1;
	$text=~tr/A-Z/a-z/;
	&checkSummarySize($tokenizedText,\$text,\$wsize,\$bsize,\$done,$lengthLimit,$byteLimit);
      }
    }
  }
  elsif($type=~/^SPL$/oi) { # SPL one Sentence Per Line format
    while(defined($line=<TEXT>)) {
      chomp($line);
      $line=~s/^\s+//;
      $line=~s/\s+$//;
      if(defined($line)&&length($line)>0) {
	$text=$line;
	$text=~tr/A-Z/a-z/;
	&checkSummarySize($tokenizedText,\$text,\$wsize,\$bsize,\$done,$lengthLimit,$byteLimit);
      }
    }
  }
  else {
    close(TEXT);
    die "Unknown input format: $type\n";
  }
  close(TEXT);
  if(defined($$tokenizedText)) {
    $$tokenizedText=~s/\-/ \- /g;
    $$tokenizedText=~s/[^A-Za-z0-9\-]/ /g;
    $$tokenizedText=~s/^\s+//;
    $$tokenizedText=~s/\s+$//;
    $$tokenizedText=~s/\s+/ /g;
  }
  else {
    print STDERR "readText: $inPath -> empty text\n";
  }
  #    print "($$tokenizedText)\n\n";
}

# enforce length cutoff at the file level
# convert different input format into SPL format then put them into
# tokenizedText
sub readText {
  my $inPath=shift;
  my $tokenizedText=shift;
  my $type=shift;
  my $lengthLimit=shift;
  my $byteLimit=shift;
  my ($text,$bsize,$wsize,@words,$done,@sntList);
  
  $$tokenizedText=undef;
  $bsize=0;
  $wsize=0;
  $done=0;
  @sntList=();
  open(TEXT,$inPath)||die "Cannot open $inPath\n";
  if($type=~/^SEE$/oi) {
    while(defined($line=<TEXT>)) { # SEE abstract format
      if($line=~/^<a size=\"[0-9]+\" name=\"[0-9]+\">\[([0-9]+)\]<\/a>\s+<a href=\"\#[0-9]+\" id=[0-9]+>([^<]+)/o||
	 $line=~/^<a name=\"[0-9]+\">\[([0-9]+)\]<\/a>\s+<a href=\"\#[0-9]+\" id=[0-9]+>([^<]+)/o) {
	$text=$2;
	$text=~tr/A-Z/a-z/;
	push(@sntList,$text);
      }
    }
  }
  elsif($type=~/^ISI$/oi) { # ISI standard sentence by sentence format
    while(defined($line=<TEXT>)) {
      if($line=~/^<S SNTNO=\"[0-9a-z,]+\">([^<]+)<\/S>/o) {
	$text=$1;
	$text=~tr/A-Z/a-z/;
	push(@sntList,$text);
      }
    }
  }
  elsif($type=~/^SPL$/oi) { # SPL one Sentence Per Line format
    while(defined($line=<TEXT>)) {
      chomp($line);
      if(defined($line)&&length($line)>0) {
	$text=$line;
	$text=~tr/A-Z/a-z/;
	push(@sntList,$text);
      }
    }
  }
  else {
    close(TEXT);
    die "Unknown input format: $type\n";
  }
  close(TEXT);
  if($lengthLimit==0&&$byteLimit==0) {
    $$tokenizedText=join(" ",@sntList);
  }
  elsif($lengthLimit!=0) {
    my ($tmpText);
    $tmpText="";
    $tmpTextLen=0;
    foreach $s (@sntList) {
      my ($sLen,@tokens);
      @tokens=split(/\s+/,$s);
      $sLen=scalar @tokens;
      if($tmpTextLen+$sLen<$lengthLimit) {
	if($tmpTextLen!=0) {
	  $tmpText.=" $s";
	}
	else {
	  $tmpText.="$s";
	}
	$tmpTextLen+=$sLen;
      }
      else {
	if($tmpTextLen>0) {
	  $tmpText.=" ";
	}
	$tmpText.=join(" ",@tokens[0..$lengthLimit-$tmpTextLen-1]);
	last;
      }
    }
    if(length($tmpText)>0) {
      $$tokenizedText=$tmpText;
    }
  }
  elsif($byteLimit!=0) {
    my ($tmpText);
    $tmpText="";
    $tmpTextLen=0;
    foreach $s (@sntList) {
      my ($sLen);
      $sLen=length($s);
      if($tmpTextLen+$sLen<$byteLimit) {
	if($tmpTextLen!=0) {
	  $tmpText.=" $s";
	}
	else {
	  $tmpText.="$s";
	}
	$tmpTextLen+=$sLen;
      }
      else {
	if($tmpTextLen>0) {
	  $tmpText.=" ";
	}
	$tmpText.=substr($s,0,$byteLimit-$tmpTextLen);
	last;
      }
    }
    if(length($tmpText)>0) {
      $$tokenizedText=$tmpText;
    }
  }
  if(defined($$tokenizedText)) {
    $$tokenizedText=~s/\-/ \- /g;
    $$tokenizedText=~s/[^A-Za-z0-9\-]/ /g;
    $$tokenizedText=~s/^\s+//;
    $$tokenizedText=~s/\s+$//;
    $$tokenizedText=~s/\s+/ /g;
  }
  else {
    print STDERR "readText: $inPath -> empty text\n";
  }
  #    print "($$tokenizedText)\n\n";
}

sub readBE {
  my $inPath=shift;
  my $BEList=shift;
  my $type=shift;
  my ($line);
  
  open(TEXT,$inPath)||die "Cannot open $inPath\n";
  if(defined($opt_v)) {
    print STDERR "$inPath\n";
  }
  if($type=~/^SIMPLE$/oi) {
    while(defined($line=<TEXT>)) { # Simple BE triple format
      chomp($line);
      push(@{$BEList},$line);
    }
  }
  elsif($type=~/^ISI$/oi) { # ISI standard BE format
    while(defined($line=<TEXT>)) {
      # place holder
    }
  }
  else {
    close(TEXT);
    die "Unknown input format: $type\n";
  }
  close(TEXT);
  if(scalar @{$BEList} ==0) {
    print STDERR "readBE: $inPath -> empty text\n";
  }
}

sub checkSummarySize {
  my $tokenizedText=shift;
  my $text=shift;
  my $wsize=shift;
  my $bsize=shift;
  my $done=shift;
  my $lenghtLimit=shift;
  my $byteLimit=shift;
  my (@words);
  
  @words=split(/\s+/,$$text);
  if(($lengthLimit==0&&$byteLimit==0)||
     ($lengthLimit!=0&&(scalar @words)+$$wsize<=$lengthLimit)||
     ($byteLimit!=0&&length($$text)+$$bsize<=$byteLimit)) {
    if(defined($$tokenizedText)) {
      $$tokenizedText.=" $$text";
    }
    else {
      $$tokenizedText=$$text;
    }
    $$bsize+=length($$text);
    $$wsize+=(scalar @words);
  }
  elsif($lengthLimit!=0&&(scalar @words)+$$wsize>$lengthLimit) {
    if($$done==0) {
      if(defined($$tokenizedText)) {
	$$tokenizedText.=" ";
	$$tokenizedText.=join(" ",@words[0..$lengthLimit-$$wsize-1]);
      }
      else {
	$$tokenizedText=join(" ",@words[0..$lengthLimit-$$wsize-1]);
      }
      $$done=1;
    }
  }
  elsif($byteLimit!=0&&length($$text)+$$bsize>$byteLimit) {
    if($$done==0) {
      if(defined($$tokenizedText)) {
	$$tokenizedText.=" ";
	$$tokenizedText.=substr($$text,0,$byteLimit-$$bsize);
      }
      else {
	$$tokenizedText=substr($$text,0,$byteLimit-$$bsize);
	
      }
      $$done=1;
    }
  }
}

# LCS computing is based on unit and cannot lump all the text together
# as in computing ngram co-occurrences
sub readText_LCS {
  my $inPath=shift;
  my $tokenizedText=shift;
  my $type=shift;
  my $lengthLimit=shift;
  my $byteLimit=shift;
  my ($text,$t,$bsize,$wsize,$done,@sntList);
  
  @{$tokenizedText}=();
  $bsize=0;
  $wsize=0;
  $done=0;
  @sntList=();
  open(TEXT,$inPath)||die "Cannot open $inPath\n";
  if($type=~/^SEE$/oi) {
    while(defined($line=<TEXT>)) { # SEE abstract format
      if($line=~/^<a size=\"[0-9]+\" name=\"[0-9]+\">\[([0-9]+)\]<\/a>\s+<a href=\"\#[0-9]+\" id=[0-9]+>([^<]+)/o||
	 $line=~/^<a name=\"[0-9]+\">\[([0-9]+)\]<\/a>\s+<a href=\"\#[0-9]+\" id=[0-9]+>([^<]+)/o) {
	$text=$2;
	$text=~tr/A-Z/a-z/;
	push(@sntList,$text);
      }
    }
  }
  elsif($type=~/^ISI$/oi) { # ISI standard sentence by sentence format
    while(defined($line=<TEXT>)) {
      if($line=~/^<S SNTNO=\"[0-9a-z,]+\">([^<]+)<\/S>/o) {
	$text=$1;
	$text=~tr/A-Z/a-z/;
	push(@sntList,$text);
      }
    }
  }
  elsif($type=~/^SPL$/oi) { # SPL one Sentence Per Line format
    while(defined($line=<TEXT>)) {
      chomp($line);
      if(defined($line)&&length($line)>0) {
	$text=$line;
	$text=~tr/A-Z/a-z/;
	push(@sntList,$text);
      }
    }
  }
  else {
    close(TEXT);
    die "Unknown input format: $type\n";
  }
  close(TEXT);
  if($lengthLimit==0&&$byteLimit==0) {
    @{$tokenizedText}=@sntList;
  }
  elsif($lengthLimit!=0) {
    my ($tmpText);
    $tmpText="";
    $tmpTextLen=0;
    foreach $s (@sntList) {
      my ($sLen,@tokens);
      @tokens=split(/\s+/,$s);
      $sLen=scalar @tokens;
      if($tmpTextLen+$sLen<$lengthLimit) {
	$tmpTextLen+=$sLen;
	push(@{$tokenizedText},$s);
      }
      else {
	push(@{$tokenizedText},join(" ",@tokens[0..$lengthLimit-$tmpTextLen-1]));
	last;
      }
    }
  }
  elsif($byteLimit!=0) {
    my ($tmpText);
    $tmpText="";
    $tmpTextLen=0;
    foreach $s (@sntList) {
      my ($sLen);
      $sLen=length($s);
      if($tmpTextLen+$sLen<$byteLimit) {
	push(@{$tokenizedText},$s);
      }
      else {
	push(@{$tokenizedText},substr($s,0,$byteLimit-$tmpTextLen));
	last;
      }
    }
  }
  if(defined(@{$tokenizedText}>0)) {
    for($t=0;$t<@{$tokenizedText};$t++) {
      $tokenizedText->[$t]=~s/\-/ \- /g;
      $tokenizedText->[$t]=~s/[^A-Za-z0-9\-]/ /g;
      $tokenizedText->[$t]=~s/^\s+//;
      $tokenizedText->[$t]=~s/\s+$//;
      $tokenizedText->[$t]=~s/\s+/ /g;
    }
  }
  else {
    print STDERR "readText_LCS: $inPath -> empty text\n";
  }
}

# LCS computing is based on unit and cannot lump all the text together
# as in computing ngram co-occurrences
sub readText_LCS_old {
  my $inPath=shift;
  my $tokenizedText=shift;
  my $type=shift;
  my $lengthLimit=shift;
  my $byteLimit=shift;
  my ($text,$t,$bsize,$wsize,$done);
  
  @{$tokenizedText}=();
  $bsize=0;
  $wsize=0;
  $done=0;
  open(TEXT,$inPath)||die "Cannot open $inPath\n";
  if($type=~/^SEE$/oi) {
    while(defined($line=<TEXT>)) { # SEE abstract format
      if($line=~/^<a (size=\"[0-9]+\" )?name=\"[0-9]+\">\[([0-9]+)\]<\/a>\s+<a href=\"\#[0-9]+\" id=[0-9]+>([^<]+)/o) {
	$text=$3;
	$text=~tr/A-Z/a-z/;
	&checkSummarySize_LCS($tokenizedText,\$text,\$wsize,\$bsize,\$done,$lengthLimit,$byteLimit);
      }
    }
  }
  elsif($type=~/^ISI$/oi) { # ISI standard sentence by sentence format
    while(defined($line=<TEXT>)) {
      if($line=~/^<S SNTNO=\"[0-9a-z,]+\">([^<]+)<\/S>/o) {
	$text=$1;
	$text=~tr/A-Z/a-z/;
	&checkSummarySize_LCS($tokenizedText,\$text,\$wsize,\$bsize,\$done,$lengthLimit,$byteLimit);
      }
    }
  }
  elsif($type=~/^SPL$/oi) { # SPL one Sentence Per Line format
    while(defined($line=<TEXT>)) {
      chomp($line);
      $line=~s/^\s+//;
      $line=~s/\s+$//;
      if(defined($line)&&length($line)>0) {
	$text=$line;
	$text=~tr/A-Z/a-z/;
	&checkSummarySize_LCS($tokenizedText,\$text,\$wsize,\$bsize,\$done,$lengthLimit,$byteLimit);
      }
    }
  }
  else {
    close(TEXT);
    die "Unknown input format: $type\n";
  }
  close(TEXT);
  if(defined(@{$tokenizedText}>0)) {
    for($t=0;$t<@{$tokenizedText};$t++) {
      $tokenizedText->[$t]=~s/\-/ \- /g;
      $tokenizedText->[$t]=~s/[^A-Za-z0-9\-]/ /g;
      $tokenizedText->[$t]=~s/^\s+//;
      $tokenizedText->[$t]=~s/\s+$//;
      $tokenizedText->[$t]=~s/\s+/ /g;
    }
  }
  else {
    print STDERR "readText_LCS: $inPath -> empty text\n";
  }
}

sub checkSummarySize_LCS {
  my $tokenizedText=shift;
  my $text=shift;
  my $wsize=shift;
  my $bsize=shift;
  my $done=shift;
  my $lenghtLimit=shift;
  my $byteLimit=shift;
  my (@words);
  
  @words=split(/\s+/,$$text);
  if(($lengthLimit==0&&$byteLimit==0)||
     ($lengthLimit!=0&&(scalar @words)+$$wsize<=$lengthLimit)||
     ($byteLimit!=0&&length($$text)+$$bsize<=$byteLimit)) {
    push(@{$tokenizedText},$$text);
    $$bsize+=length($$text);
    $$wsize+=(scalar @words);
  }
  elsif($lengthLimit!=0&&(scalar @words)+$$wsize>$lengthLimit) {
    if($$done==0) {
      push(@{$tokenizedText},$$text);
      $$done=1;
    }
  }
  elsif($byteLimit!=0&&length($$text)+$$bsize>$byteLimit) {
    if($$done==0) {
      push(@{$tokenizedText},$$text);
      $$done=1;
    }
  }
}

# EDIT-WE
# Sends HTTP Post requests to our Python server to retrieve the 
#   similarity scores between two words
sub word2vec {
    my $w1 = shift;
    my $w2 = shift;
  
    # Input words can be n-grams, tokens separated by spaces
    
    my $resp = $ua->request(
            POST $server_endpoint,
            Content_Type => 'form-data',
            Content=> [
                word1 => $w1,
                word2 => $w2
            ]
    );
    if ($resp->is_success() ) {
        if ($resp->content_type() eq "text/json") {
            #decode_json('{"status":1}');
            my $decoded_json = decode_json( $resp->decoded_content );
            my $status = $decoded_json->{'status'};
            if ($status == 1) {
                my $cosim =  $decoded_json->{'word2vec_sim'};
                return $cosim;
            } else {
                print( "word2vec returned error." );
                return 0.0;
            }
        } else {
        }
        return 0.0;
    } else {
        print( "Unable to post HTTP request." );
        return 0.0;
    }
    
}

# EDIT-WE
sub ngramWord2VecScore {
  my $model_grams=shift;
  my $peer_grams=shift;
  my $hit=shift;
  my $score=shift;
  my ($s,$t,@tokens);
  
  $$hit=0;
  @tokens=keys (%$model_grams);
  ## Check each token in model summary
  my %seen_grams = ();
  foreach $t (@tokens) {
    if($t ne "_cn_") {
      ## Modification
      my $h_orig;
      $h_orig = 0;
      ## Original code takes the smaller frequency count in either
      ##   peer_grams or model_grams as the "hit" count,
      ##   which is the count of the number of times there is a match
      if(exists($peer_grams->{$t})) {
        $h_orig=$peer_grams->{$t}<=$model_grams->{$t}?
              $peer_grams->{$t}:$model_grams->{$t}; # clip
              #  $$hit+=$h;  # ROUGE-WE uses word2vec instead of this
      }
      #
      ## Instead of the above computation for $$hit, we cycle
      ##   through all peer_grams and compute its word2vec similarity
      ##   instead.
      ## Note _cn_ is a count of the total number of tokens
      ##   that is why we ignore it in our for loop below
      @peer_tokens = keys( %$peer_grams );
      my $h_word2vec;
      $h_word2vec = 0;
      foreach $pt (@peer_tokens) {
          if ($pt ne "_cn_" ) {

            # Tracks the number of time we have seen the peer token
            if (not exists($seen_grams{$pt})) {
                $seen_grams{ $pt } = 1;
            } else {
                $seen_grams{ $pt } += 1;
            }

            # Skip ngrams we have already processed to mimick "clipping"
            # behavior of original rouge
            if ($seen_grams{$pt} <= $model_grams->{$t}) {
                # Take the word2vec difference between target token
                #  and reference peer token
                $h_word2vec += word2vec( $t, $pt );
            }
        } ## if ...
      } ## $pt

      # Combine orig ROUGE overlap score with word2vec score
      my $linear_weight;
      $linear_weight = 0.5;
      $$hit += ($linear_weight * $h_orig) + ((1 - $linear_weight) * $h_word2vec);

    }
  }
  if($model_grams->{"_cn_"}!=0) {
    $$score=sprintf("%07.5f",$$hit/$model_grams->{"_cn_"});
  }
  else {
    # no instance of n-gram at this length
    $$score=0;
    #	die "model n-grams has zero instance\n";
  }
}

# In original ROUGE-1.5.5, skipBigramScore_orig()
# is a replica of ngramScore(). This means  that a call to 
# skipBigramScore() can be changed to ngramWord2VecScore() 
#   without affecting functionality

# Note, not changed to support ROUGE-WE. Do not use for ROUGE-WE
sub lcs {
  my $model=shift;
  my $peer=shift;
  my $hit=shift;
  my $score=shift;
  my $base=shift;
  my $model_1grams=shift;
  my $peer_1grams=shift;
  my ($i,$j,@hitMask,@LCS);
  
  $$hit=0;
  $$base=0;
  # compute LCS length for each model/peer pair
  for($i=0;$i<@{$model};$i++) {
    # use @hitMask to make sure multiple peer hit won't be counted as multiple hits
    @hitMask=();
    for($j=0;$j<@{$model->[$i]};$j++) {
      push(@hitMask,0); # initialize hit mask
    }
    $$base+=scalar @{$model->[$i]}; # add model length
    for($j=0;$j<@{$peer};$j++) {
      &lcs_inner($model->[$i],$peer->[$j],\@hitMask);
    }
    @LCS=();
    for($j=0;$j<@{$model->[$i]};$j++) {
      if($hitMask[$j]==1) {
	if(exists($model_1grams->{$model->[$i][$j]})&&
	   exists($peer_1grams->{$model->[$i][$j]})&&
	   $model_1grams->{$model->[$i][$j]}>0&&
	   $peer_1grams->{$model->[$i][$j]}>0) {
	  $$hit++;
	  #---------------------------------------------
	  # bookkeeping to clip over counting
	  # everytime a hit is found it is deducted
	  # from both model and peer unigram count
	  # if a unigram count already involve in
	  # one LCS match then it will not be counted
	  # if it match another token in the model
	  # unit. This will make sure LCS score
	  # is always lower than unigram score
	  $model_1grams->{$model->[$i][$j]}--;
	  $peer_1grams->{$model->[$i][$j]}--;
	  push(@LCS,$model->[$i][$j]);
	}
      }
    }
    if($debug) {
      print "LCS: ";
      if(@LCS) {
	print join(" ",@LCS),"\n";
      }
      else {
	print "-\n";
      }
    }
  }
  if($$base>0) {
    $$score=$$hit/$$base;
  }
  else {
    $$score=0;
  }
}

sub lcs_inner {
  my $model=shift;
  my $peer=shift;
  my $hitMask=shift;
  my $m=scalar @$model; # length of model
  my $n=scalar @$peer; # length of peer
  my ($i,$j);
  my (@c,@b);
  
  if(@{$model}==0) {
    return;
  }
  @c=();
  @b=();
  # initialize boundary condition and
  # the DP array
  for($i=0;$i<=$m;$i++) {
    push(@c,[]);
    push(@b,[]);
    for($j=0;$j<=$n;$j++) {
      push(@{$c[$i]},0);
      push(@{$b[$i]},0);
    }
  }
  for($i=1;$i<=$m;$i++) {
    for($j=1;$j<=$n;$j++) {
      if($model->[$i-1] eq $peer->[$j-1]) {
	# recursively solve the i-1 subproblem
	$c[$i][$j]=$c[$i-1][$j-1]+1;
	$b[$i][$j]="\\"; # go diagonal
      }
      elsif($c[$i-1][$j]>=$c[$i][$j-1]) {
	$c[$i][$j]=$c[$i-1][$j];
	$b[$i][$j]="^"; # go up
      }
      else {
	$c[$i][$j]=$c[$i][$j-1];
	$b[$i][$j]="<"; # go left
      }
    }
  }
  &markLCS($hitMask,\@b,$m,$n);
}

sub wlcs {
  my $model=shift;
  my $peer=shift;
  my $hit=shift;
  my $score=shift;
  my $base=shift;
  my $weightFactor=shift;
  my $model_1grams=shift;
  my $peer_1grams=shift;
  my ($i,$j,@hitMask,@LCS,$hitLen);
  
  $$hit=0;
  $$base=0;
  # compute LCS length for each model/peer pair
  for($i=0;$i<@{$model};$i++) {
    # use @hitMask to make sure multiple peer hit won't be counted as multiple hits
    @hitMask=();
    for($j=0;$j<@{$model->[$i]};$j++) {
      push(@hitMask,0); # initialize hit mask
    }
    $$base+=&wlcsWeight(scalar @{$model->[$i]},$weightFactor); # add model length
    for($j=0;$j<@{$peer};$j++) {
      &wlcs_inner($model->[$i],$peer->[$j],\@hitMask,$weightFactor);
    }
    @LCS=();
    $hitLen=0;
    for($j=0;$j<@{$model->[$i]};$j++) {
      if($hitMask[$j]==1) {
	if(exists($model_1grams->{$model->[$i][$j]})&&
	   exists($peer_1grams->{$model->[$i][$j]})&&
	   $model_1grams->{$model->[$i][$j]}>0&&
	   $peer_1grams->{$model->[$i][$j]}>0) {
	  $hitLen++;
	  if($j+1<@{$model->[$i]}&&$hitMask[$j+1]==0) {
	    $$hit+=&wlcsWeight($hitLen,$weightFactor);
	    $hitLen=0; # reset hit length
	  }
	  elsif($j+1==@{$model->[$i]}) {
	    # end of sentence
	    $$hit+=&wlcsWeight($hitLen,$weightFactor);
	    $hitLen=0; # reset hit length
	  }
	  #---------------------------------------------
	  # bookkeeping to clip over counting
	  # everytime a hit is found it is deducted
	  # from both model and peer unigram count
	  # if a unigram count already involve in
	  # one LCS match then it will not be counted
	  # if it match another token in the model
	  # unit. This will make sure LCS score
	  # is always lower than unigram score
	  $model_1grams->{$model->[$i][$j]}--;
	  $peer_1grams->{$model->[$i][$j]}--;
	  push(@LCS,$model->[$i][$j]);
	}
      }
    }
    if($debug) {
      print "ROUGE-W: ";
      if(@LCS) {
	print join(" ",@LCS),"\n";
      }
      else {
	print "-\n";
      }
    }
  }
  $$score=wlcsWeightInverse($$hit/$$base,$weightFactor);
}

sub wlcsWeight {
  my $r=shift;
  my $power=shift;
  
  return $r**$power;
}

sub wlcsWeightInverse {
  my $r=shift;
  my $power=shift;
  
  return $r**(1/$power);
}

sub wlcs_inner {
  my $model=shift;
  my $peer=shift;
  my $hitMask=shift;
  my $weightFactor=shift;
  my $m=scalar @$model; # length of model
  my $n=scalar @$peer; # length of peer
  my ($i,$j);
  my (@c,@b,@l);
  
  if(@{$model}==0) {
    return;
  }
  @c=();
  @b=();
  @l=(); # the length of consecutive matches so far
  # initialize boundary condition and
  # the DP array
  for($i=0;$i<=$m;$i++) {
    push(@c,[]);
    push(@b,[]);
    push(@l,[]);
    for($j=0;$j<=$n;$j++) {
      push(@{$c[$i]},0);
      push(@{$b[$i]},0);
      push(@{$l[$i]},0);
    }
  }
  for($i=1;$i<=$m;$i++) {
    for($j=1;$j<=$n;$j++) {
      if($model->[$i-1] eq $peer->[$j-1]) {
	# recursively solve the i-1 subproblem
	$k=$l[$i-1][$j-1];
	$c[$i][$j]=$c[$i-1][$j-1]+&wlcsWeight($k+1,$weightFactor)-&wlcsWeight($k,$weightFactor);
	$b[$i][$j]="\\"; # go diagonal
	$l[$i][$j]=$k+1; # extend the consecutive matching sequence
      }
      elsif($c[$i-1][$j]>=$c[$i][$j-1]) {
	$c[$i][$j]=$c[$i-1][$j];
	$b[$i][$j]="^"; # go up
	$l[$i][$j]=0; # no match at this position
      }
      else {
	$c[$i][$j]=$c[$i][$j-1];
	$b[$i][$j]="<"; # go left
	$l[$i][$j]=0; # no match at this position
      }
    }
  }
  &markLCS($hitMask,\@b,$m,$n);
}

sub markLCS {
  my $hitMask=shift;
  my $b=shift;
  my $i=shift;
  my $j=shift;
  
  while($i!=0&&$j!=0) {
    if($b->[$i][$j] eq "\\") {
      $i--;
      $j--;
      $hitMask->[$i]=1; # mark current model position as a hit
    }
    elsif($b->[$i][$j] eq "^") {
      $i--;
    }
    elsif($b->[$i][$j] eq "<") {
      $j--;
    }
    else {
      die "Illegal move in markLCS: ($i,$j): \"$b->[$i][$j]\".\n";
    }
  }
}

# currently only support simple lexical matching
sub getBEScore {
  my $modelBEs=shift;
  my $peerBEs=shift;
  my $hit=shift;
  my $score=shift;
  my ($s,$t,@tokens);
  
  $$hit=0;
  @tokens=keys (%$modelBEs);
  foreach $t (@tokens) {
    if($t ne "_cn_") {
      my $h;
      $h=0;
      if(exists($peerBEs->{$t})) {
	$h=$peerBEs->{$t}<=$modelBEs->{$t}?
	  $peerBEs->{$t}:$modelBEs->{$t}; # clip
	$$hit+=$h;
	if(defined($opt_v)) {
	  print "* Match: $t\n";
	}
      }
    }
  }
  if($modelBEs->{"_cn_"}!=0) {
    $$score=sprintf("%07.5f",$$hit/$modelBEs->{"_cn_"});
  }
  else {
    # no instance of BE at this length
    $$score=0;
    #	die "model BE has zero instance\n";
  }
}

sub MorphStem {
  my $token=shift;
  my ($os,$ltoken);
  
  if(!defined($token)||length($token)==0) {
    return undef;
  }
  
  $ltoken=$token;
  $ltoken=~tr/A-Z/a-z/;
  if(exists($exceptiondb{$ltoken})) {
    return $exceptiondb{$ltoken};
  }
  $os=$ltoken;
  return stem($os);
}

sub createNGram {
  my $text=shift;
  my $g=shift;
  my $NSIZE=shift;
  my @mx_tokens=();
  my @m_tokens=();
  my ($i,$j);
  my ($gram);
  my ($count);
  my ($byteSize);
  
  # remove stopwords
  if($useStopwords) {
    %stopwords=(); # consider stop words
  }
  unless(defined($text)) {
    $g->{"_cn_"}=0;
    return;
  }
  @mx_tokens=split(/\s+/,$text);
  $byteSize=0;
  for($i=0;$i<=$#mx_tokens;$i++) {
    unless(exists($stopwords{$mx_tokens[$i]})) {
      $byteSize+=length($mx_tokens[$i])+1; # the length of words in bytes so far + 1 space 
      if($mx_tokens[$i]=~/^[a-z0-9\$]/o) {
	if(defined($opt_m)) {
	  # use stemmer
	  # only consider words starting with these characters
	  # use Porter stemmer
	  my $stem;
	  $stem=$mx_tokens[$i];
	  if(length($stem)>3) {
	    push(@m_tokens,&MorphStem($stem));
	  }
	  else { # no stemmer as default
	    push(@m_tokens,$mx_tokens[$i]);
	  }
	}
	else { # no stemmer
	  push(@m_tokens,$mx_tokens[$i]);
	}
      }
    }
  }
  #-------------------------------------
  # create ngram
  $count=0;
  for($i=0;$i<=$#m_tokens-$NSIZE+1;$i++) {
    $gram=$m_tokens[$i];
    for($j=$i+1;$j<=$i+$NSIZE-1;$j++) {
      $gram.=" $m_tokens[$j]";
    }
    $count++;
    unless(exists($g->{$gram})) {
      $g->{$gram}=1;
    }
    else {
      $g->{$gram}++;
    }
  }
  # save total number of tokens
  $g->{"_cn_"}=$count;
}

sub createSkipBigram {
  my $text=shift;
  my $g=shift;
  my $skipDistance=shift;
  my @mx_tokens=();
  my @m_tokens=();
  my ($i,$j);
  my ($gram);
  my ($count);
  my ($byteSize);
  
  # remove stopwords
  if($useStopwords) {
    %stopwords=(); # consider stop words
  }
  unless(defined($text)) {
    $g->{"_cn_"}=0;
    return;
  }
  @mx_tokens=split(/\s+/,$text);
  $byteSize=0;
  for($i=0;$i<=$#mx_tokens;$i++) {
    unless(exists($stopwords{$mx_tokens[$i]})) {
      $byteSize+=length($mx_tokens[$i])+1; # the length of words in bytes so far + 1 space 
      if($mx_tokens[$i]=~/^[a-z0-9\$]/o) {
	if(defined($opt_m)) {
	  # use stemmer
	  # only consider words starting with these characters
	  # use Porter stemmer
	  my $stem;
	  $stem=$mx_tokens[$i];
	  if(length($stem)>3) {
	    push(@m_tokens,&MorphStem($stem));
	  }
	  else { # no stemmer as default
	    push(@m_tokens,$mx_tokens[$i]);
	  }
	}
	else { # no stemmer
	  push(@m_tokens,$mx_tokens[$i]);
	}
      }
    }
  }
  #-------------------------------------
  # create ngram
  $count=0;
  for($i=0;$i<$#m_tokens;$i++) {
    if(defined($opt_u)) {
      # add unigram count
      $gram=$m_tokens[$i];
      $count++;
      unless(exists($g->{$gram})) {
	$g->{$gram}=1;
      }
      else {
	$g->{$gram}++;
      }
    }
    for($j=$i+1;
	$j<=$#m_tokens&&($skipDistance<0||$j<=$i+$skipDistance+1);
	$j++) {
      $gram=$m_tokens[$i];
      $gram.=" $m_tokens[$j]";
      $count++;
      unless(exists($g->{$gram})) {
	$g->{$gram}=1;
      }
      else {
	$g->{$gram}++;
      }
    }
  }
  # save total number of tokens
  $g->{"_cn_"}=$count;
}

sub createBE {
  my $BEList=shift;
  my $BEMap=shift;
  my $BEMode=shift;
  my ($i);
  
  $BEMap->{"_cn_"}=0;
  unless(scalar @{$BEList} > 0) {
    return;
  }
  for($i=0;$i<=$#{$BEList};$i++) {
    my (@fds);
    my ($be,$stemH,$stemM);
    $be=$BEList->[$i];
    $be=~tr/A-Z/a-z/;
    @fds=split(/\|/,$be);
    if(@fds!=3) {
      print STDERR "Basic Element (BE) input file is invalid: *$be*\n";
      print STDERR "A BE file has to be in this format per line: HEAD|MODIFIER|RELATION\n";
      die "For more infomation about BE, go to: http://www.isi.edu/~cyl/BE\n";
    }
    $stemH=$fds[0];
    $stemM=$fds[1];
    if(defined($opt_m)) {
      # use stemmer
      # only consider words starting with these characters
      # use Porter stemmer
      if(length($stemH)>3) {
	$stemH=&MorphStemMulti($stemH);
      }
      if($stemM ne "NIL"&&
	 length($stemM)>3) {
	$stemM=&MorphStemMulti($stemM);
      }
    }
    if($BEMode eq "H"&&
      $stemM eq "nil") {
      unless(exists($BEMap->{$stemH})) {
	$BEMap->{$stemH}=0;
      }
      $BEMap->{$stemH}++;
      $BEMap->{"_cn_"}++;
    }
    elsif($BEMode eq "HM"&&
	  $stemM ne "nil") {
      my $pair="$stemH|$stemM";
      unless(exists($BEMap->{$pair})) {
	$BEMap->{$pair}=0;
      }
      $BEMap->{$pair}++;
      $BEMap->{"_cn_"}++;
    }
    elsif($BEMode eq "HMR"&&
	  $fds[2] ne "nil") {
      my $triple="$stemH|$stemM|$fds[2]";
      unless(exists($BEMap->{$triple})) {
	$BEMap->{$triple}=0;
      }
      $BEMap->{$triple}++;
      $BEMap->{"_cn_"}++;
    }
    elsif($BEMode eq "HM1") {
      my $pair="$stemH|$stemM";
      unless(exists($BEMap->{$pair})) {
	$BEMap->{$pair}=0;
      }
      $BEMap->{$pair}++;
      $BEMap->{"_cn_"}++;
    }
    elsif($BEMode eq "HMR1"&&
	  $fds[1] ne "nil") { 
      # relation can be "NIL" but modifier has to have value
      my $triple="$stemH|$stemM|$fds[2]";
      unless(exists($BEMap->{$triple})) {
	$BEMap->{$triple}=0;
      }
      $BEMap->{$triple}++;
      $BEMap->{"_cn_"}++;
    }
    elsif($BEMode eq "HMR2") {
      # modifier and relation can be "NIL"
      my $triple="$stemH|$stemM|$fds[2]";
      unless(exists($BEMap->{$triple})) {
	$BEMap->{$triple}=0;
      }
      $BEMap->{$triple}++;
      $BEMap->{"_cn_"}++;
    }
  }
}

sub MorphStemMulti {
  my $string=shift;
  my (@tokens,@stems,$t,$i);
  
  @tokens=split(/\s+/,$string);
  foreach $t (@tokens) {
    if($t=~/[A-Za-z0-9]/o&&
       $t!~/(-LRB-|-RRB-|-LSB-|-RSB-|-LCB-|-RCB-)/o) {
      my $s;
      if(defined($s=&MorphStem($t))) {
	$t=$s;
      }
      push(@stems,$t);
    }
    else {
      push(@stems,$t);
    }
  }
  return join(" ",@stems);
}

sub tokenizeText {
  my $text=shift;
  my $tokenizedText=shift;
  my @mx_tokens=();
  my ($i,$byteSize);
  
  # remove stopwords
  if($useStopwords) {
    %stopwords=(); # consider stop words
  }
  unless(defined($text)) {
    return;
  }
  @mx_tokens=split(/\s+/,$text);
  $byteSize=0;
  @{$tokenizedText}=();
  for($i=0;$i<=$#mx_tokens;$i++) {
    unless(exists($stopwords{$mx_tokens[$i]})) {
      $byteSize+=length($mx_tokens[$i])+1; # the length of words in bytes so far + 1 space 
      if($mx_tokens[$i]=~/^[a-z0-9\$]/o) {
	if(defined($opt_m)) {
	  # use stemmer
	  # only consider words starting with these characters
	  # use Porter stemmer
	  my $stem;
	  $stem=$mx_tokens[$i];
	  if(length($stem)>3) {
	    push(@{$tokenizedText},&MorphStem($stem));
	  }
	  else { # no stemmer as default
	    push(@{$tokenizedText},$mx_tokens[$i]);
	  }
	}
	else { # no stemmer
	  push(@{$tokenizedText},$mx_tokens[$i]);
	}
      }
    }
  }
}

sub tokenizeText_LCS {
  my $text=shift;
  my $tokenizedText=shift;
  my $lengthLimit=shift;
  my $byteLimit=shift;
  my @mx_tokens=();
  my ($i,$byteSize,$t,$done);
  
  # remove stopwords
  if($useStopwords) {
    %stopwords=(); # consider stop words
  }
  if(@{$text}==0) {
    return;
  }
  $byteSize=0;
  @{$tokenizedText}=();
  $done=0;
  for($t=0;$t<@{$text}&&$done==0;$t++) {
    @mx_tokens=split(/\s+/,$text->[$t]);
    # tokenized array for each separate unit (for example, sentence)
    push(@{$tokenizedText},[]);
    for($i=0;$i<=$#mx_tokens;$i++) {
      unless(exists($stopwords{$mx_tokens[$i]})) {
	$byteSize+=length($mx_tokens[$i])+1; # the length of words in bytes so far + 1 space 
	if($mx_tokens[$i]=~/^[a-z0-9\$]/o) {
	  if(defined($opt_m)) {
	    # use stemmer
	    # only consider words starting with these characters
	    # use Porter stemmer
	    my $stem;
	    $stem=$mx_tokens[$i];
	    if(length($stem)>3) {
	      push(@{$tokenizedText->[$t]},&MorphStem($stem));
	    }
	    else { # no stemmer as default
	      push(@{$tokenizedText->[$t]},$mx_tokens[$i]);
	    }
	  }
	  else { # no stemmer
	    push(@{$tokenizedText->[$t]},$mx_tokens[$i]);
	  }
	}
      }
    }
  }
}

# Input file configuration is a list of peer/model pair for each evaluation
# instance. Each evaluation pair is in a line separated by white spaces
# characters.
sub readFileList {
  my ($ROUGEEvals)=shift;
  my ($ROUGEEvalIDs)=shift;
  my ($ROUGEPeerIDTable)=shift;
  my ($doc)=shift;
  my ($evalID,$pair);
  my ($inputFormat,$peerFile,$modelFile,$peerID,$modelID);
  my (@files);

  $evalID=1;  # automatically generated evaluation ID starting from 1
  $peerID=$systemID;
  $modelID="M";
  unless(exists($ROUGEPeerIDTable->{$peerID})) {
    $ROUGEPeerIDTable->{$peerID}=1;
  }
  while(defined($pair=<$doc>)) {
    my ($peerPath,$modelPath);
    if($pair!~/^\#/o&&
       $pair!~/^\s*$/o) { # Lines start with '#' is a comment line
      chomp($pair);
      $pair=~s/^\s+//;
      $pair=~s/\s+$//;
      @files=split(/\s+/,$pair);
      if(scalar @files < 2) {
	die "File list has to have at least 2 filenames per line (peer model1 model2 ... modelN)\n";
      }
      $peerFile=$files[0];
      unless(exists($ROUGEEvals->{$evalID})) {
	$ROUGEEvals->{$evalID}={};
	push(@{$ROUGEEvalIDs},$evalID);
	$ROUGEEvals->{$evalID}{"IF"}=$opt_z;
      }
      unless(exists($ROUGEPeerIDTable->{$peerID})) {
	$ROUGEPeerIDTable->{$peerID}=1; # save peer ID for reference
      }
      if(exists($ROUGEEvals->{$evalID})) {
	unless(exists($ROUGEEvals->{$evalID}{"Ps"})) {
	  $ROUGEEvals->{$evalID}{"Ps"}={};
	  $ROUGEEvals->{$evalID}{"PIDList"}=[];
	}
	push(@{$ROUGEEvals->{$evalID}{"PIDList"}},$peerID); # save peer IDs
      }
      else {
	die "(PEERS) Evaluation database does not contain entry for this evaluation ID: $evalID\n";
      }
      # remove leading and trailing newlines and
      # spaces
      if(exists($ROUGEEvals->{$evalID}{"Ps"})) {
	$ROUGEEvals->{$evalID}{"Ps"}{$peerID}=$peerFile; # save peer filename
      }
      else {
	die "(P) Evaluation database does not contain entry for this evaluation ID: $evalID\n";
      }
      for($mid=1;$mid<=$#files;$mid++) {
	$modelFile=$files[$mid];
	if(exists($ROUGEEvals->{$evalID})) {
	  unless(exists($ROUGEEvals->{$evalID}{"Ms"})) {
	    $ROUGEEvals->{$evalID}{"Ms"}={};
	    $ROUGEEvals->{$evalID}{"MIDList"}=[];
	  }
	  push(@{$ROUGEEvals->{$evalID}{"MIDList"}},"$modelID.$mid"); # save model IDs
	}
	else {
	  die "(MODELS) Evaluation database does not contain entry for this evaluation ID: $evalID\n";
	}
	# remove leading and trailing newlines and
	# spaces
	if(exists($ROUGEEvals->{$evalID}{"Ms"})) {
	  $ROUGEEvals->{$evalID}{"Ms"}{"$modelID.$mid"}=$modelFile; # save peer filename
	}
	else {
	  die "(M) Evaluation database does not contain entry for this evaluation ID: $evalID\n";
	}
      }
      $evalID++;
    }
  }
}

# read and parse ROUGE evaluation file
sub readEvals {
  my ($ROUGEEvals)=shift;
  my ($ROUGEEvalIDs)=shift;
  my ($ROUGEPeerIDTable)=shift;
  my ($node)=shift;
  my ($evalID)=shift;
  my ($inputFormat,$peerRoot,$modelRoot,$peerFile,$modelFile,$peerID,$modelID);
  
  if(defined($opt_z)) {
    # Input file configuration is a list of peer/model pair for each evaluation
    # instance. Each evaluation pair is in a line separated by white spaces
    # characters.
    &readFileList($ROUGEEvals,$ROUGEEvalIDs,$ROUGEPeerIDTable,$node);
    return;
  }
  # Otherwise, the input file is the standard ROUGE XML evaluation configuration
  # file.
  if($node->getNodeType==ELEMENT_NODE||
     $node->getNodeType==DOCUMENT_NODE) {
    if($node->getNodeType==ELEMENT_NODE) {
      $nodeName=$node->getNodeName;
      if($nodeName=~/^EVAL$/oi) {
	$evalID=$node->getAttributeNode("ID")->getValue;
	unless(exists($ROUGEEvals->{$evalID})) {
	  $ROUGEEvals->{$evalID}={};
	  push(@{$ROUGEEvalIDs},$evalID);
	}
	foreach my $child ($node->getChildNodes()) {
	  &readEvals($ROUGEEvals,$ROUGEEvalIDs,$ROUGEPeerIDTable,$child,$evalID);
	}
      }
      elsif($nodeName=~/^INPUT-FORMAT$/oi) {
	$inputFormat=$node->getAttributeNode("TYPE")->getValue;
	if($inputFormat=~/^(SEE|ISI|SPL|SIMPLE)$/oi) { # SPL: one sentence per line
	  if(exists($ROUGEEvals->{$evalID})) {
	    $ROUGEEvals->{$evalID}{"IF"}=$inputFormat;
	  }
	  else {
	    die "(INPUT-FORMAT) Evaluation database does not contain entry for this evaluation ID: $evalID\n";
	  }
	}
	else {
	  die "Unknown input type: $inputFormat\n";
	}
      }
      elsif($nodeName=~/^PEER-ROOT$/oi) {
	foreach my $child ($node->getChildNodes()) {
	  if($child->getNodeType==TEXT_NODE) {
	    $peerRoot=$child->getData;
	    # remove leading and trailing newlines and
	    # spaces
	    $peerRoot=~s/^[\n\s]+//;
	    $peerRoot=~s/[\n\s]+$//;
	    if(exists($ROUGEEvals->{$evalID})) {
	      $ROUGEEvals->{$evalID}{"PR"}=$peerRoot;
	    }
	    else {
	      die "(PEER-ROOT) Evaluation database does not contain entry for this evaluation ID: $evalID\n";
	    }
	  }
	}
      }
      elsif($nodeName=~/^MODEL-ROOT$/oi) {
	foreach my $child ($node->getChildNodes()) {
	  if($child->getNodeType==TEXT_NODE) {
	    $modelRoot=$child->getData;
	    # remove leading and trailing newlines and
	    # spaces
	    $modelRoot=~s/^[\n\s]+//;
	    $modelRoot=~s/[\n\s]+$//;
	    if(exists($ROUGEEvals->{$evalID})) {
	      $ROUGEEvals->{$evalID}{"MR"}=$modelRoot;
	    }
	    else {
	      die "(MODEL-ROOT) Evaluation database does not contain entry for this evaluation ID: $evalID\n";
	    }
	  }
	}
      }
      elsif($nodeName=~/^PEERS$/oi) {
	foreach my $child ($node->getChildNodes()) {
	  if($child->getNodeType==ELEMENT_NODE&&
	     $child->getNodeName=~/^P$/oi) {
	    $peerID=$child->getAttributeNode("ID")->getValue;
	    unless(exists($ROUGEPeerIDTable->{$peerID})) {
	      $ROUGEPeerIDTable->{$peerID}=1; # save peer ID for reference
	    }
	    if(exists($ROUGEEvals->{$evalID})) {
	      unless(exists($ROUGEEvals->{$evalID}{"Ps"})) {
		$ROUGEEvals->{$evalID}{"Ps"}={};
		$ROUGEEvals->{$evalID}{"PIDList"}=[];
	      }
	      push(@{$ROUGEEvals->{$evalID}{"PIDList"}},$peerID); # save peer IDs
	    }
	    else {
	      die "(PEERS) Evaluation database does not contain entry for this evaluation ID: $evalID\n";
	    }
	    foreach my $grandchild ($child->getChildNodes()) {
	      if($grandchild->getNodeType==TEXT_NODE) {
		$peerFile=$grandchild->getData;
		# remove leading and trailing newlines and
		# spaces
		$peerFile=~s/^[\n\s]+//;
		$peerFile=~s/[\n\s]+$//;
		if(exists($ROUGEEvals->{$evalID}{"Ps"})) {
		  $ROUGEEvals->{$evalID}{"Ps"}{$peerID}=$peerFile; # save peer filename
		}
		else {
		  die "(P) Evaluation database does not contain entry for this evaluation ID: $evalID\n";
		}
	      }
	    }
	  }
	}
      }
      elsif($nodeName=~/^MODELS$/oi) {
	foreach my $child ($node->getChildNodes()) {
	  if($child->getNodeType==ELEMENT_NODE&&
	     $child->getNodeName=~/^M$/oi) {
	    $modelID=$child->getAttributeNode("ID")->getValue;
	    if(exists($ROUGEEvals->{$evalID})) {
	      unless(exists($ROUGEEvals->{$evalID}{"Ms"})) {
		$ROUGEEvals->{$evalID}{"Ms"}={};
		$ROUGEEvals->{$evalID}{"MIDList"}=[];
	      }
	      push(@{$ROUGEEvals->{$evalID}{"MIDList"}},$modelID); # save model IDs
	    }
	    else {
	      die "(MODELS) Evaluation database does not contain entry for this evaluation ID: $evalID\n";
	    }
	    foreach my $grandchild ($child->getChildNodes()) {
	      if($grandchild->getNodeType==TEXT_NODE) {
		$modelFile=$grandchild->getData;
		# remove leading and trailing newlines and
		# spaces
		$modelFile=~s/^[\n\s]+//;
		$modelFile=~s/[\n\s]+$//;
		if(exists($ROUGEEvals->{$evalID}{"Ms"})) {
		  $ROUGEEvals->{$evalID}{"Ms"}{$modelID}=$modelFile; # save peer filename
		}
		else {
		  die "(M) Evaluation database does not contain entry for this evaluation ID: $evalID\n";
		}
	      }
	    }
	  }
	}
      }
      else {
	foreach my $child ($node->getChildNodes()) {
	  &readEvals($ROUGEEvals,$ROUGEEvalIDs,$ROUGEPeerIDTable,$child,$evalID);
	}
      }
    }
    else {
      foreach my $child ($node->getChildNodes()) {
	&readEvals($ROUGEEvals,$ROUGEEvalIDs,$ROUGEPeerIDTable,$child,$evalID);
      }
    }
  }
  else {
    if(defined($node->getChildNodes())) {
      foreach my $child ($node->getChildNodes()) {
	&readEvals($ROUGEEvals,$ROUGEEvalIDs,$ROUGEPeerIDTable,$child,$evalID);
      }
    }
  }
}

# Porter stemmer in Perl. Few comments, but it's easy to follow against the rules in the original
# paper, in
#
#   Porter, 1980, An algorithm for suffix stripping, Program, Vol. 14,
#   no. 3, pp 130-137,
#
# see also http://www.tartarus.org/~martin/PorterStemmer

# Release 1

local %step2list;
local %step3list;
local ($c, $v, $C, $V, $mgr0, $meq1, $mgr1, $_v);


sub stem
  {  my ($stem, $suffix, $firstch);
     my $w = shift;
     if (length($w) < 3) { return $w; } # length at least 3
     # now map initial y to Y so that the patterns never treat it as vowel:
     $w =~ /^./; $firstch = $&;
     if ($firstch =~ /^y/) { $w = ucfirst $w; }
     
     # Step 1a
     if ($w =~ /(ss|i)es$/) { $w=$`.$1; }
     elsif ($w =~ /([^s])s$/) { $w=$`.$1; }
     # Step 1b
     if ($w =~ /eed$/) { if ($` =~ /$mgr0/o) { chop($w); } }
     elsif ($w =~ /(ed|ing)$/)
       {  $stem = $`;
	  if ($stem =~ /$_v/o)
	    {  $w = $stem;
	       if ($w =~ /(at|bl|iz)$/) { $w .= "e"; }
	       elsif ($w =~ /([^aeiouylsz])\1$/) { chop($w); }
	       elsif ($w =~ /^${C}${v}[^aeiouwxy]$/o) { $w .= "e"; }
   }
}
# Step 1c
  if ($w =~ /y$/) { $stem = $`; if ($stem =~ /$_v/o) { $w = $stem."i"; } }

# Step 2
if ($w =~ /(ational|tional|enci|anci|izer|bli|alli|entli|eli|ousli|ization|ation|ator|alism|iveness|fulness|ousness|aliti|iviti|biliti|logi)$/)
  { $stem = $`; $suffix = $1;
    if ($stem =~ /$mgr0/o) { $w = $stem . $step2list{$suffix}; }
  }

# Step 3

if ($w =~ /(icate|ative|alize|iciti|ical|ful|ness)$/)
  { $stem = $`; $suffix = $1;
    if ($stem =~ /$mgr0/o) { $w = $stem . $step3list{$suffix}; }
  }

# Step 4

   # CYL: Modified 02/14/2004, a word ended in -ement will not try the rules "-ment" and "-ent"
#   if ($w =~ /(al|ance|ence|er|ic|able|ible|ant|ement|ment|ent|ou|ism|ate|iti|ous|ive|ize)$/)
#   elsif ($w =~ /(s|t)(ion)$/)
#   { $stem = $` . $1; if ($stem =~ /$mgr1/o) { $w = $stem; } }
   if ($w =~ /(al|ance|ence|er|ic|able|ible|ant|ement|ou|ism|ate|iti|ous|ive|ize)$/)
   { $stem = $`; if ($stem =~ /$mgr1/o) { $w = $stem; } }
   if ($w =~ /ment$/)
   { $stem = $`; if ($stem =~ /$mgr1/o) { $w = $stem; } }
   if ($w =~ /ent$/)
   { $stem = $`; if ($stem =~ /$mgr1/o) { $w = $stem; } }
   elsif ($w =~ /(s|t)(ion)$/)
   { $stem = $` . $1; if ($stem =~ /$mgr1/o) { $w = $stem; } }

#  Step 5

if ($w =~ /e$/)
  { $stem = $`;
    if ($stem =~ /$mgr1/o or
	($stem =~ /$meq1/o and not $stem =~ /^${C}${v}[^aeiouwxy]$/o))
{ $w = $stem; }
}
if ($w =~ /ll$/ and $w =~ /$mgr1/o) { chop($w); }

# and turn initial Y back to y
if ($firstch =~ /^y/) { $w = lcfirst $w; }
return $w;
}

  sub initialise {
    
    %step2list =
      ( 'ational'=>'ate', 'tional'=>'tion', 'enci'=>'ence', 'anci'=>'ance', 'izer'=>'ize', 'bli'=>'ble',
	'alli'=>'al', 'entli'=>'ent', 'eli'=>'e', 'ousli'=>'ous', 'ization'=>'ize', 'ation'=>'ate',
	'ator'=>'ate', 'alism'=>'al', 'iveness'=>'ive', 'fulness'=>'ful', 'ousness'=>'ous', 'aliti'=>'al',
	'iviti'=>'ive', 'biliti'=>'ble', 'logi'=>'log');
    
    %step3list =
      ('icate'=>'ic', 'ative'=>'', 'alize'=>'al', 'iciti'=>'ic', 'ical'=>'ic', 'ful'=>'', 'ness'=>'');
    
    
    $c =    "[^aeiou]";          # consonant
    $v =    "[aeiouy]";          # vowel
    $C =    "${c}[^aeiouy]*";    # consonant sequence
    $V =    "${v}[aeiou]*";      # vowel sequence
    
    $mgr0 = "^(${C})?${V}${C}";               # [C]VC... is m>0
    $meq1 = "^(${C})?${V}${C}(${V})?" . '$';  # [C]VC[V] is m=1
   $mgr1 = "^(${C})?${V}${C}${V}${C}";       # [C]VCVC... is m>1
   $_v   = "^(${C})?${v}";                   # vowel in stem

}

