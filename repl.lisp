#!/usr/bin/env sbcl --script
(load "~/quicklisp/setup")

(let ((*standard-output* (make-broadcast-stream)))
  (ql:quickload "alexandria")
  (ql:quickload "cl-readline"))

(defvar *repl-version* "0.0.2")
(defvar *repl-name*    "Veit's REPL for SBCL")
(defvar *prompt*       "sbcl> ")
(defvar *ret*          "=> ")
(defvar *config-file*  "~/.sbclirc")

(format t "~a version ~a~%" *repl-name* *repl-version*)
(format t "Press CTRL-C or CTRL-D or type :q to exit~%~%")
(finish-output nil)

(defun end ()
  (format t "Bye for now.~%")
  (exit))

(defun split (str chr)
  (loop for i = 0 then (1+ j)
        as j = (position chr str :start i)
        collect (subseq str i j)
        while j))

(defun novelty-check (str1 str2)
  (string/= (string-trim " " str1)
            (string-trim " " str2)))

(defun custom-complete (text start end)
  (declare (ignore start) (ignore end))
  (labels ((common-prefix (items)
             (let ((lst 0))
              (loop for n from 1 below (reduce #'min (mapcar #'length items)) do
                (when (every (lambda (x)
                             (char= (char (car items) n)
                                    (char x           n)))
                         (cdr items))
                  (setf lst n)))
              (write lst)
              (subseq (car items) 0 (+ lst 1))))
           (starts-with (text)
             (lambda (sym)
               (let* ((symstr (string-downcase sym))
                      (cmp (subseq symstr 0 (min (length symstr) (length text)))))
                 (string= text cmp))))
           (select-completions (list)
             (let* ((els (remove-if-not (starts-with text)
                                       (mapcar #'string list)))
                    (els (if (cdr els) (cons (common-prefix els) els) els)))
                (if (string= text (string-downcase text))
                  (mapcar #'string-downcase els)
                  els)))
           (get-all-symbols ()
             (let ((lst ()))
               (do-all-symbols (s lst)
                 (when (fboundp s) (push s lst)))
               lst)))
      (select-completions (get-all-symbols))))

(rl:register-function :complete #'custom-complete)

(defun main ()
  (let ((text
          (rl:readline :prompt (if (functionp *prompt*) (funcall *prompt*) *prompt*)
                       :add-history t
                       :novelty-check #'novelty-check)))
    (if (not text) (end))
    (if (and (> (length text) 1) (string= (subseq text 0 2) ":h"))
      (let ((splt (split text #\Space)))
        (inspect (intern (cadr splt))))
      (let ((parsed
         (handler-case (read-from-string text)
           (error (condition) (format t "Parser error: ~a~%" condition)))))
        (if parsed
          (let ((res
                  (handler-case (eval parsed)
                    (unbound-variable (var) (format t "~a~%" var))
                    (undefined-function (fun) (format t "~a~%" fun))
                    (sb-int:compiled-program-error () (format t "Compiler error.~%"))
                    (error (condition) (format t "Compiler error: ~a~%" condition)))))
            (if (eq res :q) (end))
            (if res (format t "~a~a~%" *ret* res))))))
    (finish-output nil)
    (main)))

(if (probe-file *config-file*)
  (load *config-file*))

(handler-case (main)
  (sb-sys:interactive-interrupt () (end)))
