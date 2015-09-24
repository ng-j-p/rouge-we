# rouge-we
ROUGE summarization evaluation metric, enhanced with use of Word Embeddings
 as described in:
 
 **Better Summarization Evaluation with Word Embeddings for ROUGE**  
   *Jun-Ping Ng and Viktoria Abrecht*  
   *in Proceedings of the Conference on Empirical Methods in Natural Language Processing (EMNLP), 2015*

https://scholar.google.com/citations?view_op=view_citation&hl=en&user=Sf5qT74AAAAJ&citation_for_view=Sf5qT74AAAAJ:D_sINldO8mEC

 
For any questions, you may get in touch with me via email:
Jun-Ping Ng
email@junping.ng


OVERVIEW
==========
This program helps compute the ROUGE-WE scores of summaries.
ROUGE-WE builds on top of ROUGE (http://www.berouge.com).

REQUISITES
==========

You will need the following:

1. word2vec pre-trained vectors
https://drive.google.com/file/d/0B7XkCwpI5KDYNlNUTTlSS21pQmM/edit?usp=sharing

USAGE
==========

1. Start up the word2vec query server:
>? python word2vec_server.m.py -m <Path To pre-trained vectors>

2. Test the word2vec query server by sending a HTTP Post request to:
http://localhost:8888/word2vecdiff

You can do this in a variety of ways, such as by using curl. The following examples work in OS X:

>? curl -X POST --data "word1=king&word2=queen" http://localhost:8888/word2vecdiff  
>{"status": 1, "word2vec_sim": 0.651095648143}
>
>? curl -X POST --data "word1=raining heavily&word2=snowing badly" http://localhost:8888/word2vecdiff  
>{"status": 1, "word2vec_sim": 0.293822419014}

3. Run ROUGE-WE in the same way you would with ROUGE-1.5.5.pl

> NOTE: First create the necessary config file. A sample has been pre-created.
> Some sample data is found in rouge_1.5.5_data and the XML required is
> given in sample-config.xml
>? ./ROUGE-WE-1.0.0.pl -x -n 2 -U -2 4 -e rouge_1.5.5_data/ -c 95 -a sample-config.xml

Sample output:

---------------------------------------------  
1 ROUGE-1 Average_R: 0.23145 (95%-conf.int. 0.23145 - 0.23145)  
1 ROUGE-1 Average_P: 0.27279 (95%-conf.int. 0.27279 - 0.27279)  
1 ROUGE-1 Average_F: 0.25043 (95%-conf.int. 0.25043 - 0.25043)  
---------------------------------------------  
1 ROUGE-2 Average_R: 0.05782 (95%-conf.int. 0.05782 - 0.05782)  
1 ROUGE-2 Average_P: 0.06894 (95%-conf.int. 0.06894 - 0.06894)   
1 ROUGE-2 Average_F: 0.06289 (95%-conf.int. 0.06289 - 0.06289) 
---------------------------------------------  
1 ROUGE-S4 Average_R: 0.03988 (95%-conf.int. 0.03988 - 0.03988)  
1 ROUGE-S4 Average_P: 0.04894 (95%-conf.int. 0.04894 - 0.04894)  
1 ROUGE-S4 Average_F: 0.04395 (95%-conf.int. 0.04395 - 0.04395)  
......
......

ROADMAP
===========

An update is under development, which does away with the Python based web server, and directly loads the word2vec vectors inside Perl instead. I hope to get this done real soon.