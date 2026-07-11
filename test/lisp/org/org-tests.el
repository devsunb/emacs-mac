;;; org-tests.el --- tests for org/org.el  -*- lexical-binding:t -*-

;; Copyright (C) 2018-2026 Free Software Foundation, Inc.

;; Maintainer: emacs-devel@gnu.org

;; This file is part of GNU Emacs.

;; GNU Emacs is free software: you can redistribute it and/or modify
;; it under the terms of the GNU General Public License as published by
;; the Free Software Foundation, either version 3 of the License, or
;; (at your option) any later version.

;; GNU Emacs is distributed in the hope that it will be useful,
;; but WITHOUT ANY WARRANTY; without even the implied warranty of
;; MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
;; GNU General Public License for more details.

;; You should have received a copy of the GNU General Public License
;; along with GNU Emacs.  If not, see <https://www.gnu.org/licenses/>.

;;; Commentary:

;;; Code:

(require 'cl-lib)
(require 'org)

(ert-deftest org-package-version ()
  "Test Version: header is present and correct.
Ref <https://debbugs.gnu.org/30310>."
  (should (require 'org-version nil t))
  (should (equal (version-to-list (org-release))
                 (cdr (assq 'org package--builtin-versions)))))

(ert-deftest org-create-formula-image-keeps-separate-1x-and-2x-results ()
  "Test that the 1x and 2x files each get their own conversion's output."
  (let* ((directory (make-temp-file "org-formula-image-" t))
         (temporary-file-directory directory)
         (tofile (expand-file-name "formula.png" directory))
         (to2xfile (expand-file-name "formula@2x.png" directory))
         (org-preview-latex-process-alist
          '((test :programs nil
                  :image-input-type "pdf"
                  :image-output-type "png"
                  :latex-header ""
                  :latex-compiler ("latex")
                  :image-converter ("convert")
                  :post-clean (".tex" ".pdf" ".png"))))
         converter-specs)
    (unwind-protect
        (cl-letf (((symbol-function 'org-latex-color-format)
                   (lambda (_color) "0,0,0"))
                  ((symbol-function 'org-compile-file)
                   (lambda (source _process extension
                                   &optional _err-msg _log-buf spec)
                     (when spec (push spec converter-specs))
                     (let ((output (concat (file-name-sans-extension source)
                                           "." extension)))
                       (with-temp-file output
                         (insert (if spec (alist-get ?D spec) "input")))
                       output))))
          (org-create-formula-image
           "x" tofile (list :html-scale 1.0 :to2xfile to2xfile) nil 'test)
          (should (= (length converter-specs) 2))
          (let* ((dpi (lambda (spec) (string-to-number (alist-get ?D spec))))
                 (specs (sort converter-specs
                              (lambda (a b) (< (funcall dpi a)
                                               (funcall dpi b)))))
                 (spec-1x (car specs))
                 (spec-2x (cadr specs)))
            (should (= (funcall dpi spec-2x) (* 2 (funcall dpi spec-1x))))
            (should (equal (alist-get ?S spec-2x)
                           (alist-get ?S spec-1x)))
            (should (equal (with-temp-buffer
                             (insert-file-contents tofile)
                             (buffer-string))
                           (alist-get ?D spec-1x)))
            (should (equal (with-temp-buffer
                             (insert-file-contents to2xfile)
                             (buffer-string))
                           (alist-get ?D spec-2x)))))
      (delete-directory directory t))))

;;; org-tests.el ends here
