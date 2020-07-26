;;; -*- Mode: LISP; Base: 10; Syntax: ANSI-Common-Lisp; Package: CL-USER -*-
;;; Copyright (c) 2020 by Symbolics Pte. Ltd. All rights reserved.

(asdf:defsystem #:spark
  :description "Wrapper for Spark 3.0"
  :author "Steve Nunez"
  :license  "Boost"
  :version "0.1"
  :serial t
  :defsystem-depends-on (abcl-asdf)
  :depends-on (#:jss #:javaparser)
  :components ((:mvn  "org.apache.spark/spark-core_2.12" :version "3.0.0")
	       (:mvn  "org.apache.hadoop/hadoop-client") ; Needed even for local filesystem access (? TBC)
	       (:file "package")
	       (:file "utils")
               (:file "spark")
	       (:file "hello-world")))



;;; Important Note

;;; Several tutorials on Maven 3 configuration state that, post Maven
;;; 3.5, that you should not set the MAVEN_HOME or M2_HOME environment
;;; variables. For example this thread on stackoverflow:
;;; https://stackoverflow.com/questions/26609922/maven-home-mvn-home-or-m2-home
;;; The abcl-asdf setup however requires M2_HOME, so ensure that this
;;; environment variable is set.
