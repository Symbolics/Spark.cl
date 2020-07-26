;;; -*- Mode: LISP; Base: 10; Syntax: ANSI-Common-Lisp; Package: SPARK -*-
;;; Copyright (c) 2020 by Symbolics Pte. Ltd. All rights reserved.
(in-package #:spark)

(defun jlist-from-list (list)
  "Return an Array back Java list"
  (let ((jlist (jss::new 'arraylist)))
    (loop for el in list
        do (#"add" jlist el))
    jlist))
