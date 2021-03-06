;;; ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

;; To configure this script, search for "(and #" and substitute #true or #false as required.

;; It's currently configured to run the last PubMed document processing pipeling in this file. 

;; To run, execute the following command in bash after making appropriate directory substitutions:

;; nohup /Applications/Racket/bin/racket -f /Users/adammarblestone/Desktop/ScientificSearching/scratcher.scm > NOHUP.out 2> NOHUP.err < /dev/null &

;;; ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

;; TODO: Segment references into sentences - all of the cited article titles are concatenated 
;;       into one long string. Segmentation is a bit tricky since the titles are generally not 
;;       full sentences, and, in particular they usually lack any end-of-sentence punctuation.  
;;
;; TODO: All articles will require NER (Named Entity Recognition) annotation, in particular
;;       we need a basis for standard names for genes, molecules, proteins, organisms, etc.
;;       We'll likely need more than Freebase and Wikipedia to get comprehensive coverage.

;;; ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

#lang racket

(require racket/block)   ;;; Substitute for the obscure PROGN block of ancient lisp dialects.

(require racket/control) ;;; Defines ABORT and other useful flow-of-control structures:

(require xml)            ;;; XML parser tools for extracting text data from the NXML files.

(require xml/path)       ;;; Simple XML path queries, e.g., <back><ref-list><ref><citation>.

;;; ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

;; Additional scripts here - /u/tld/programming/scheme/zinn/archive/scratcher.06-20-14a.scm

;;; ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

(define-values (verbose-diagnostic-messages run-unit-tests) (values #f #f))

(define-syntax diagnostic-block
  (syntax-rules ()
    ((_ form ...)
     (and verbose-diagnostic-messages (block form ...)))))

(define-syntax unit-test-block
  (syntax-rules ()
    ((_ form ...)
     (and run-unit-tests (block form ...)))))

;;; ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

(define dataset-directory "/users/adammarblestone/Desktop/PubMed/")

;;; Here is the directory structure for the PubMed dataset assumed in the following scripts:

;;;             /PubMed/shards/SHARD-000001
;;;                            SHARD-000002
;;;                            ...
;;;                     corpus/A-B/Brain/Brain_2000_ ... .nxml
;;;                                      Brain_2003_ ... .nxml
;;;                                Brain_Cell_Biol/Brain_Cell_Biol_2006_ ... .nxml
;;;                                                Brain_Cell_Biol_2008_ ... .nxml
;;;                                                ...
;;;                            C-H/ ...
;;;                            I-N/ ...   
;;;                            O-Z/Oecologia/Oecologia_2013_ ... .nxml
;;;                                          ...
;;;                                ...
;;;                                Zoomorphology/Zoomorphology_1999_ ... .nxml
;;;                                             ...

;;; ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

(and #false
 (let ([count 0])
   (for ([path (in-directory  dataset-directory )]
         #:when (regexp-match #px".nxml$" path))
        (set! count (+ 1 count)))
   (printf "~a~n" count)) )

;; 813,335 papers: 

(and #false
 (let ([successes 0] [total-count 0] [failures 0] 
       [lynx-cmd null] [word-count null] 
       [lynx-pat "/opt/local/bin/lynx -force_html -dump \"file://localhost~a\" | wc -w"])
   (for ([path (in-directory  dataset-directory )]
         ;; Sample 1 in 1000 papers to estimate total words:
         #:when (and (= 0 (random 800))
                     (regexp-match #px".nxml$" path)))
        (with-handlers ([exn:fail? (lambda (exn)
                                     (printf "FAILED ON: ~a~n" path)
                                     (set! failures (+ 1 failures)))])
                       ;; Format LYNX command for counting words:
                       (set! lynx-cmd (format lynx-pat path))
                       (set! word-count (string->number 
                                         (string-trim
                                          (with-output-to-string 
                                            (lambda () (system lynx-cmd))))))
                       (set! successes (+ 1 successes))
                       (set! total-count (+ total-count word-count))))
   (printf "SUCCESSES: ~a~n" successes)
   (printf "FAILURES: ~a~n" failures)
   (printf "TOTAL WORD COUNT: ~a~n" total-count)
   (printf "AVERAGE WORD COUNT: ~a~n" (/ total-count successes))) )

;; SUCCESSES: 1033
;; FAILURES: 0
;; TOTAL WORD COUNT: 4632151
;; AVERAGE WORD COUNT: 4484.17328

;; 3,647,135,076 estimated words:

(define (format-integer-leading-zeros num width)
  (let* ([str (number->string num)]
         [len (string-length str)])
    (if (> len width)
        str
        (string-append (make-string (- width len) #\0) str))))

;; 3,579,353,881 actual words:

;; 557 50MB files: 50 * 557 = 27,850MB or 27.1972GB disk space:

(and #false
 (let ([successes 0] [failures 0] [lynx-cmd null] [word-count null] 
       [shard-file null] [shard-limit 50000000] [shard-count 0] [field-width 6]
       [lynx-pat "/opt/local/bin/lynx -force_html -dump \"file://localhost~a\" >> ~a"])
   (for ([data-file (in-directory dataset-directory)]
         #:when (regexp-match #px".nxml$" data-file))
        ;; Check current shard and create new shard as needed:
        (and (or (null? shard-file)
                 (> (file-size shard-file) shard-limit))
             (block 
              (set! shard-count (+ 1 shard-count))
              (set! shard-file
                    (format "~acorpus/SHARD-~a" dataset-directory
                            (format-integer-leading-zeros shard-count field-width)))
              (if (file-exists? shard-file) 
                  (delete-file shard-file) "OK")
              (system (format "/usr/bin/touch ~a" shard-file))))
        ;; Format LYNX command for piping text to shard file:
        (set! lynx-cmd (format lynx-pat data-file shard-file))
        (with-handlers ([exn:fail? (lambda (exn)
                                     (printf "FAILED ON: ~a~n" data-file)
                                     (set! failures (+ 1 failures)))])
                       (system lynx-cmd)
                       (set! successes (+ 1 successes))))
   (printf "SUCCESSES: ~a~n" successes)
   (printf "FAILURES: ~a~n" failures)) )

;; Examples:

(unit-test-block 
 (let* ([lynx-cmd-test (string-append
                        "lynx -force_html -dump \"file://localhost" dataset-directory "corpus/A-B/"
                        "Brain_Cell_Biol/Brain_Cell_Biol_2006_Dec_5_35(4-6)_229-237.nxml\" | wc -w")]
        [out (with-output-to-string (lambda () (system lynx-cmd-test)))])
   (printf "~a~n" (string->number (string-trim out)))) )

;;; ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

(define (resolve-symbol-entities code)
  (case code
    ;; UNICODE SYMBOL DESCRIPTION
    [ (34)     "\"" ] ;; quotation mark = APL quote
    [ (38)     "&"  ] ;; ampersand
    [ (60)     "<"  ] ;; less-than sign
    [ (62)     ">"  ] ;; greater-than sign
    [ (8211)   "-"  ] ;; en dash
    [ (8212)   "-"  ] ;; em dash
    [ (8216)   "`"  ] ;; left single quotation mark
    [ (8217)   "'"  ] ;; right single quotation mark, right single inverted comma, apostrophe
    [ (8218)   "'"  ] ;; single low-9 quotation mark
    [ (8220)   "\"" ] ;; left double quotation mark
    [ (8221)   "\"" ] ;; right double quotation mark
    [ (8222)   "\"" ] ;; double low-9 quotation mark
    [ (8230)   "..."] ;; horizontal ellipsis = three dot leader
    [ (8240)   " per thousand" ] ;; per mille sign
    [ (8242)   "'"  ] ;; prime = minutes = feet
    [ (8243)   "''" ] ;; double prime = seconds = inches
    [ (8249)   "<"  ] ;; single left-pointing angle quotation mark
    [ (8250)   ">"  ] ;; single right-pointing angle quotation mark
    [ (8260)   "/"  ] ;; fraction slash
    [else      " "  ])) ;; default is to insert a space

(define (resolve-latin-entities str)
  (regexp-replaces (format "~a" str)
                   (list (list #px"cf\\."     "COMPARING")
                         (list #px"Dr\\."     "DOCTOR")
                         (list #px"et al\\."  "AND CO-AUTHORS")
                         (list #px"e\\.g\\."  "FOR EXAMPLE")
                         (list #px"etc\\."    "AND THE REST")
                         (list #px"Fig\\."    "FIGURE")
                         (list #px"i\\.e\\."  "THAT IS")
                         (list #px"ibid\\."   "IBID")
                         (list #px"Mr\\."     "MISTER")
                         (list #px"Mrs\\."    "MRS")
                         (list #px"Ms\\."     "MISS")
                         (list #px"Ph\\.D\\." "DOCTOR")
                         (list #px"sic\\."    "AS WRITTEN")
                         (list #px"stat\\."   "IMMEDIATELY")
                         (list #px"viz\\."    "NAMELY"))))

;;; ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

(define (html-to-text contents)
  (string-normalize-spaces 
   (resolve-latin-entities
    (string-append* 
     (map (lambda (content)
            (cond ((string? content) (string-append content " "))
                  ((number? content) (resolve-symbol-entities content))
                  ((and (list? content) 
                        (> (length content) 2)
                        (string? (third content))
                        (memq (car content) '(xref italic)))
                   (third content))
                  (else "")))
          contents)) )))

;;; ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

(define (string-to-words str)
  (let ([words (regexp-split #px"[[:space:]]+" 
                             (regexp-replace* #px"[^ [:word:]'-]" str ""))])
    (set! words (remove* (list "") words (lambda (u v) (string=? u v))))
    (if (not (ormap (lambda (word) (string=? "" word)) words))
        words
        (error "STRING-TO-WORDS: match includes empty string"))))

;; Examples:

(unit-test-block
 (let ((str "This is a segment. It consists of sentences, which consist of words."))
   (= 12 (length (string-to-words str)))) )

;;; ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

(define sentence-regexp (pregexp "[A-Z]([^.!?]|([.][^[:space:]]))+[.!?](?=($|([[:space:]]+[A-Z])))"))

(define (string-to-sentences str) (regexp-match* sentence-regexp str))

;; Examples:

(unit-test-block
 (let ([str "This is the first. This is the second, i.e., the sentence numbered two!  The third?"])
   (regexp-match* sentence-regexp str)) )

;;; ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

(define (list-of-strings? contents)
  (and (list? contents) (andmap (lambda (content) (string? content)) contents)))

;;; ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

(define (write-content-to-shard-file content #:port [port (current-output-port)])
  (with-handlers ([exn:fail? (lambda (exn) #false)])
                 (if (string? content)
                     (fprintf port "~a~n" content)
                     (if (not (list-of-strings? content))
                         (error "WRITE-CONTENT-TO-SHARD-FILE: failed contract!")
                         (for ([line content]
                               #:when (> (string-length line) 0))
                              (fprintf port "~a~n" line)))) #true))

;;; ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

;;    (define input 
;;     (xml->xexpr 
;;      (document-element 
;;       (read-xml 
;;        (open-input-file 
;;         "/u/tld/Desktop/PubMed/A-B/Brain/Brain_2008_Aug_20_131(8)_2181-2191.nxml"))))))

;;; ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

(define (pubmed-extract-article-content input-path output-path)
  (let ([input-port (open-input-file input-path)] [input null]
        [output-port (open-output-file output-path #:exists 'append)])
    (with-handlers ([exn:fail? (lambda (exn) 
                                 ;; Clean up - close open ports:
                                 (close-input-port input-port)
                                 (close-output-port output-port) #false)])
                   (set! input (xml->xexpr (document-element (read-xml input-port))))
                   ;; Handle text corresponding to titles not sentences:
                   (for ([path (list 
                                ;; Journal title - expect one title string:
                                '(front journal-meta journal-title)
                                ;; Article title - expect one title string:
                                '(front article-meta title-group article-title)
                                ;; Reference titles - list of title strings:
                                '(back ref-list ref citation article-title))])
                        (write-content-to-shard-file 
                         (html-to-text (se-path*/list path input)) #:port output-port))

                   ;; Handle text corresponding to one or more sentences:
                   (for ([path (list 
                                ;; Abstract, etc - expect a string:
                                '(front article-meta abstract p)
                                ;; Preface, etc - expect HTML/XML:
                                '(body p)
                                ;; Methods, etc - expect HTML/XML:
                                '(body sec p))])
                        (write-content-to-shard-file 
                         (string-to-sentences 
                          (html-to-text (se-path*/list path input))) #:port output-port))
                   ;; Clean up - close open ports:
                   (close-input-port input-port)
                   (close-output-port output-port) #true)))

;; Examples:

(unit-test-block
 (let ([input-path (build-path dataset-directory "corpus" "A-B" 
                               "Brain/Brain_2008_Aug_20_131(8)_2181-2191.nxml")]
       [output-path "/u/tld/Desktop/PubMed/TMP.FILE"])
   (pubmed-extract-article-content input-path output-path))

 (let ([input-path (build-path dataset-directory "corpus" "A-B" 
                               "Brain_Cell_Biol/Brain_Cell_Biol_2006_Dec_5_35(4-6)_229-237.nxml")]
       [output-path "/u/tld/Desktop/PubMed/TMP.FILE"])
   (pubmed-extract-article-content input-path output-path)) )

;;; ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

(and #true
 (let ([successes 0] [failures 0] [field-width 6]
       [output-file null] [shard-limit 50000000] [shard-counter 0]) 
   (for ([input-file (in-directory (build-path dataset-directory "corpus"))]
         #:when (regexp-match #px".nxml$" input-file))
        ;; Check current shard and create new shard as needed:
        (and (or (null? output-file)
                 (> (file-size output-file) shard-limit))
             (block 
              (set! shard-counter (+ 1 shard-counter))
              (set! output-file
                    (build-path dataset-directory "shards"
                                (format "SHARD-~a"
                                        (format-integer-leading-zeros 
                                         shard-counter field-width))))
              (if (file-exists? output-file) 
                  (delete-file output-file) "OK")
              (system (format "/usr/bin/touch ~a" output-file))))
        (with-handlers ([exn:fail? (lambda (exn)
                                     (printf "FAILED ON: ~a~n" input-file)
                                     (set! failures (+ 1 failures)))])
                       (cond ((pubmed-extract-article-content input-file output-file)
                              (set! successes (+ 1 successes)))
                             (else (set! failures (+ 1 failures))
                                   (printf "FAILED ON: ~a~n" input-file)))))
   (printf "SUCCESSES: ~a~n" successes)
   (printf "FAILURES: ~a~n" failures)) )

;;; ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
