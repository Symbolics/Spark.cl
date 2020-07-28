;;; -*- Mode: LISP; Base: 10; Syntax: ANSI-Common-Lisp; Package: SPARK -*-
;;; Copyright (c) 2020 by Symbolics Pte. Ltd. All rights reserved.
(in-package #:spark)

;;; This is an annotated conversion of the 'hello world' (introductory
;;; tutorial) in the Spark RDD Programming Guide.
;;; http://spark.apache.org/docs/latest/rdd-programming-guide.html It
;;; is intended to be instructional and demonstrate options and best
;;; practices when using ABCL to interoperate with large Java
;;; libraries.
;;; TODO:SN: Convert this to an org or MD file when it's done.

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;;
;;; Change the class loader so we can locate the Spark resource files
;;;

;;; TODO: Explain why we need to change the class loader
;;; TODO: Write the same function using the JAVA package instead of JSS; could also go in the docs at section 3.1.1
(defun change-class-loader ()
  "Need a function until ABCL bug #338 is fixed"
  (#"setContextClassLoader" #1"Thread.currentThread()" (java:get-current-classloader)))
(change-class-loader)


;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;;
;;; Create some special variables for Spark
;;;

;;; You often see a 'chain' pattern in Java, where multiple function
;;; calls appear together. For example the code below appears
;;; originally as SparkConf conf = new
;;; SparkConf().setAppName(appName).setMaster(master) In ABCL we can
;;; achieve the same affect with java:chain, as we do below.
(defun make-spark-config (&key (app-name "abcl-app") (master "local"))
  "Return a spark configuration.
Required to work around ABCL bug 338, otherwise we'd just do this at a
top-level form. See https://abcl.org/trac/ticket/338"
  (let ((conf (jss:new (jss:find-java-class "org.apache.spark.sparkConf")))) ; Do we need find-java-class ?
    (java:chain conf
                ("setAppName" app-name)
                ("setMaster"  master))))


(defun make-spark-context (spark-config)
  "No JSS as  atop level form. Wrap in a function."
  (jss:new 'JavaSparkContext spark-config))

;;; Spark requires one, and only one, context. You'll probably want to
;;; set these to a different value. These are here as a convenience
;;; when getting started. This example uses a remote master. I had
;;; difficulty getting a master to run on MS Windows. Having the Spark
;;; context local (on Windows) and sending the jobs to the remote
;;; master works well though.
(defvar *spark-conf* (make-spark-config :master "spark://spark:7077")) ; Change master to suit your setup
(defvar *sc*         (make-spark-context *spark-conf*))


;;; This is neccessary, but not sufficient, to use Spark on MS
;;; Windows. Generally, running Spark on MS Windows was an uphill
;;; battle for me and using a remote master on a UNIX VM an easier
;;; route.
(defun set-hadoop-configuration ()
  "Configure Spark to use a local file system as the default for file:/// scheme

Spark uses Hadoop JARs to read files, even when the files are on the
local file system. Spark is not configured by default to use the local
filesystem, even in 'local' master."
  (let ((hadoop-configuration (#"hadoopConfiguration" *sc*)))
    (#"set" hadoop-configuration "fs.file.impl" (#"getName" (jss:find-java-class "org.apache.hadoop.fs.LocalFileSystem")))))
(set-hadoop-configuration)



;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;;
;;; Load and process data
;;;

;;; The Spark tutorial demonstrates using the _parallelize_ method on
;;; a java.util.list. In this case a list of Java Integers is obtained
;;; with: List<Integer> data = Arrays.asList(1, 2, 3, 4, 5);

;;; It's helpful to know here that a java.util.list isn't a list in
;;; the Lisp sense, it's more akin to a SEQUENCE, with various
;;; implementions, one of which is Array. The Spark tutorial uses
;;; Array to back the SEQUENCE, so one way to write this in ABCL is
;;; using "asList", which converts an array to a list (SN: I don't
;;; quite understand the conversion since java.util.list is a
;;; superclass; figure out and explain):

#+Ignore
(progn
  (#"parallelize" *sc* (#"asList" 'Arrays (java:jarray-from-list '(1 2 3 4 5)))) )

;;; Whist this looks like the long way around, Alan R. explains "In
;;; this case it's not really going the long way around. #"asList"
;;; takes a variable number of arguments - its java method signature
;;; is (T... a). JSS doesn't yet know about varargs. The way java
;;; implements varags is to actually create a method that takes an
;;; array of the arguments, and then when calling the method, add code
;;; to pack the arguments into an array. That's what you did - pack
;;; the arguments into an array, doing what the java compiler would
;;; do.
;;; See https://stackoverflow.com/questions/21746663/how-does-jvm-implement-the-varargs

;;; A more idiomatic way, using a JSS utility function is this:

;; I thought we needed progn here because JSS can't be used in a top
;; level form, but this doesn't work either
#+Ignore
(progn
  (#"parallelize" *sc* (jlist-from-list '(1 2 3 4 5))))


;;; TODO: Insert some mention of Java's implementation of Arrays,
;;; Lists and other collections and how they map onto ABCL data
;;; structures. Examples of common conversions, defaults,
;;; non-defaults. As a start:

;;; From Alessio Stalla:
;;; "You should know that ABCL lists are not Java List<T>
;;; instances. There are some automatic conversions (e.g., from Lisp
;;; numbers to Java numbers) but not for lists or hash tables."

;;; I don't understand the rest of his note, but it looks like it
;;; might be helpful...

;;; "Granted, it wouldn't be much work to either have Cons implement
;;; List<LispObject> or provide a cons-backed List<T extends
;;; LispObject> implementation. However, the devil is in the details
;;; how do you convert those LispObject's to the appropriate Java
;;; type? Is it Integer, Long, Double, ...? Generics are erased at
;;; runtime, ABCL couldn't possibly know, so we'd need another
;;; primitive, e.g., (jcoerce-collection collection &key element-type
;;; (collection-type "java.util.ArrayList")). But then one would have
;;; to know about it in order to use it."

;;; What you really need to know about Java arrays is this: Arrays are
;;; primitive sequences of fixed size and element type. They are
;;; implemented in the JVM itself (presumably in C++). Each array has
;;; a (synthetic) array class represented in Java as <type>[].class,
;;; e.g., int[].class or String[].class or Object[][].class.  Lists
;;; are higher-level data structures, implemented in Java. They're
;;; potentially heterogeneous in element type, have variable size, and
;;; several implementations with different characteristics,
;;; particularly wrt. performance and concurrency. ArrayList is one
;;; such implementation: a List backed by a primitive array. Then
;;; there's LinkedList, etc.


;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;;
;;; External Datasets
;;;

;;; The Java code is:
;;; JavaRDD<String> distFile = sc.textFile("data.txt");
;;; In ABCL, there are two ways to do this, with JSS and with
;;; functions in the JAVA package

#+Ignore
(progn
  (defvar *lines* (#"textFile" *sc* "/usr/local/spark/README.md"))) ; JSS syntax

;;; Be careful when looking at Java function names; camel case is
;;; important. To do this using the JAVA package:

#+Ignore
(defvar *lines* (jcall (jmethod "org.apache.spark.api.java.JavaRDD" "textFile") *sc* "/usr/local/spark/README.md"))



;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;;
;;; Basic RDD operations
;;;

;;; Having obtained a JavaRDD in the previous step, the tutorial
;;; demonstrates mapping over each line and return its length:
;;; JavaRDD<Integer> lineLengths = lines.map(s -> s.length());

;;; This example means we'll need a lambda expression in ABCL.

#+Ignore
(progn
  (defvar *line-lengths* (#"map" *lines* ???? ))) ; How to implement a JDK8 style lambda?




;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;;
;;; Passing ABCL functions to Spark
;;;

;;; https://stackoverflow.com/questions/26817940/how-to-use-map-function-in-spark-with-java
;;; https://stackoverflow.com/questions/4785969/can-you-write-a-java-class-with-abcl
;;; https://abcl.org/trac/browser/trunk/abcl/examples/java-interface
;;; https://blog.cyrusharmon.org/blog/cyrusblog/display/140


;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;;
;;; Efficiency and Types
;;;

;;; TODO: Discuss the cost / benefits of list/array conversion. Since
;;; Spark uses some fairly large arrays, it might not be worth the
;;; cost to go to/from ABCL.

;;; In particular, one uses map and reduce often. Can we map an ABCL
;;; function over a java.util.list? If so, provide an example
;;; here. The same for reduce.
