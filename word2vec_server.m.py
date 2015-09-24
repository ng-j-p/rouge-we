###
### This python code starts up a REST-based web server which computes
###   the semantic similarity of two input words
###
### The latest version of this code can always be found at:
###    https://github.com/ng-j-p/rouge-we
###
### Jun-Ping Ng email@junping.ng
### All Rights Reserved
### Sep 2015
###

## Infrastructure for web server
from werkzeug.wrappers import Request, Response
from werkzeug.routing import Map, Rule
from werkzeug.exceptions import HTTPException, NotFound
import uuid
import signal
import sys

## Mathematical libraries
from gensim import models, similarities
import numpy
import math

## Others
import json
import threading
from time import sleep
import datetime
from optparse import OptionParser


### @brief Implements the web server which takes in words and
###          returns their similarity values
class Word2VecGateway(object):

    ### @brief Constructor
    def __init__(self, config):
    
        self.url_map = Map([
                # Shows general info about this server
                Rule('/', endpoint='usage_info'),
                # Pings the server to check if everything is fine
                Rule('/ping', endpoint='ping'),
                # Call to get similarity value
                Rule('/word2vecdiff', endpoint='word2vec_diff')
            ])
        self.word2vec_model = models.Word2Vec.load_word2vec_format(config['word2vec_model'], binary=True )

    # Ensure clean up proceeds correctly
    def cleanup(self):
        self.send_to_log("Cleaning up gateway server...")
        ## Add any clean up here

    ### PROCESSORS ###
    
    ### @brief Displays general info
    ### Usage: http://<server>:<port>/
    ###  Parameters: None
    ###
    def on_usage_info(self,request):
       info = "This gateway helps services word similarity requests."
       return Response(info, mimetype='text/plain')

    ### @brief Pings the service to ensure that everything is fine
    ### Usage: http://<server>:<port>/ping
    ###  Parameters: None
    ###
    def on_ping(self, request):
        info = '{"status": 1}'
        return Response(info, mimetype='text/json')

    ### @brief Takes in two words and returns their similarity value
    ### Usage: http://<server>:<port>/word2vec_diff
    ###  Parameters: (POST) word1, word2
    ###  Multi-word expressions are accepted, delimited by spaces:
    ###    apple
    ###    burger king 
    ###    ...
    def on_word2vec_diff(self, request):
        self.send_to_log("\non_word2vec_diff() initiated...")
        if request.method == 'POST':
            
            proceed = True
            
            # Retrieve arguments from the POST request
            word1 = str(request.form['word1'])
            word1_tokens = word1.split( " " )
            word1_vectors = [ ]
            for token in word1_tokens:
                if not token in self.word2vec_model:
                    self.send_to_log("\nWARN: Ignoring word1 OOV token: " + token )
                    info = '{"status": 1, "word2vec_sim": 0}'
                    proceed = False
                    break
                word1_vectors.append( numpy.array( self.word2vec_model[token] ) )
            
            word2 = str(request.form['word2'])
            word2_tokens = word2.split( " " )
            word2_vectors = [ ]
            for token in word2_tokens:
                if not token in self.word2vec_model:
                    self.send_to_log("\nWARN: Ignoring word2 OOV token: " + token )
                    info = '{"status": 1, "word2vec_sim": 0}'
                    proceed = False
                    break
                word2_vectors.append( numpy.array( self.word2vec_model[token] ) )

            self.send_to_log("\n-> word1: " + word1 + " - word2: " + word2)

            if proceed:
                self.send_to_log("\nComputing...")
                word1_aggregate = word1_vectors[0]
                for i in range(1,len(word1_vectors)):
                    word1_aggregate *= word1_vectors[i]
                #print word1_aggregate
                #word1_aggregate /= len( word1_vectors )
                word2_aggregate = word2_vectors[0]
                for i in range(1, len(word2_vectors)):
                    word2_aggregate *= word2_vectors[i]
                #print word2_aggregate
                #word2_aggregate /= len( word2_vectors )
                mag_word1vec = math.sqrt( numpy.dot( word1_aggregate, word1_aggregate ) )
                mag_word2vec = math.sqrt( numpy.dot( word2_aggregate, word2_aggregate ) )
                cosim_value = numpy.dot( word1_aggregate, word2_aggregate ) / ( mag_word1vec * mag_word2vec )
                #cosim_value = numpy.dot( word1_aggregate, word2_aggregate )
                info = '{"status": 1, "word2vec_sim": ' + str(cosim_value) + '}'
                self.send_to_log("\n " + word1 + " <-> " + word2 + " :" + str(cosim_value) )

        else:
            info = '{"status": -1, "message": Only POST is supported"}'
       
        self.send_to_log("\n\n -> " + info + "\n\n" )
        return Response(info, mimetype='text/json')

    ### SCAFFOLDING ###

    ### @brief Decide on the type of request we get, and dispatch it to
    ###         a suitable handler
    def dispatch_request(self, request):
        adapter = self.url_map.bind_to_environ(request.environ)
        try:
            endpoint, values = adapter.match()
            return getattr(self, 'on_' + endpoint)(request, **values)
        except HTTPException, e:
            # Log error
            self.send_to_log("Error dispatching request.") 
            # + e)
            return e

    ### @brief Part of werkzeug scaffolding.
    ### Strictly speaking not really needed, can be merged into __call__
    ###   But we'd follow the best practise as listed in the werkzeug
    ###   tutorial
    def wsgi_app(self, environ, start_response):
        request = Request(environ)
        response = self.dispatch_request(request)
        return response(environ, start_response)

    ### @brief Part of werkzeug scaffolding
    def __call__(self, environ, start_response):
        return self.wsgi_app(environ, start_response)

    ### HELPER FUNCTIONS ###

    ### @brief Logs a message to stderr
    ### @param message   [in] the message to write to stderr
    ### @return nothing
    def send_to_log(self, message):
        sys.stderr.write(message)
   
#### END OF CLASS ####


def create_app( model_file_name ):
    """
    Jump-starts the WSGI infrastructure
    """
    app = Word2VecGateway(
            {'word2vec_model': model_file_name } # Config
            )
    return app

def user_interrupt_handler(signal, frame):
    """
    This allows us to trap "CTRL-C"
    """
    app.cleanup()
    sys.exit(0)

def get_parser():
    """
    Returns a command line parser
    """
    parser = OptionParser()
    parser.add_option("-m", "--vector_file", dest="vector_file", help="Path to pre-trained word2vec vector file", type="string")
    parser.add_option("-p", "--port_num", dest="port_num", help="Port number to run server on, defaults to 8888", type="int", default="8888")
    parser.add_option("-s", "--server_address", dest="server_address", help="Server IP Address to listen on, defaults to 127.0.0.1", type="string", default="127.0.0.1")
    
    return parser

### @brief Starts the whole app from the command line 
if __name__ == '__main__':
    
    ### Parse command line arguments
    parser = get_parser()
    options,args = parser.parse_args()
    
    ### Check for required arguments, exit if not present
    if not options.vector_file:
        parser.print_usage()
        exit(1)
    
    ### Start web server which will process similarity queries
    from werkzeug.serving import run_simple

    ### Set up signal handler to allow us to stop the server with CTRL-C
    signal.signal(signal.SIGINT, user_interrupt_handler)
    
    ### Starts the WSGI server
    serverAddr = options.server_address
    portNum = options.port_num
    
    sys.stderr.write("Creating gateway application...\n")
    app = create_app( model_file_name = options.vector_file)
    
    sys.stderr.write("Starting server...\n")
    run_simple(serverAddr, portNum, app, use_debugger=True, use_reloader=False)


