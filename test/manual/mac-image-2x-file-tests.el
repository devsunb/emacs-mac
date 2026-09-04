;;; mac-image-2x-file-tests.el --- Tests for Mac @2x image files  -*- lexical-binding: t; -*-

;; Copyright (C) 2026 Free Software Foundation, Inc.

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

;; Run these tests in a Mac GUI session.  They force Emacs's recorded
;; backing scale to 1, independently of the connected display.
;;
;; They need `image--set-test-frame-backing-scale-factor', which only
;; exists in a build configured with --enable-checking.

;;; Code:

(require 'ert)
(require 'image)

(defconst mac-image-2x-file-tests--xbm-8x8
  "#define t_width 8
#define t_height 8
static char t_bits[] = {
  0xff, 0x81, 0x81, 0x81, 0x81, 0x81, 0x81, 0xff };
"
  "8x8 XBM image, a hollow square.")

(defconst mac-image-2x-file-tests--xbm-16x16
  "#define t_width 16
#define t_height 16
static char t_bits[] = {
  0xff, 0xff, 0x01, 0x80, 0x01, 0x80, 0x01, 0x80,
  0x01, 0x80, 0x01, 0x80, 0x01, 0x80, 0x01, 0x80,
  0x01, 0x80, 0x01, 0x80, 0x01, 0x80, 0x01, 0x80,
  0x01, 0x80, 0x01, 0x80, 0x01, 0x80, 0xff, 0xff };
"
  "16x16 XBM image, the @2x counterpart of `mac-image-2x-file-tests--xbm-8x8'.")

(ert-deftest mac-image-2x-file-tests-scale-1-reads-the-1x-file ()
  "On a scale-1 frame an @2x sibling does not replace the file read."
  (skip-unless (and (eq window-system 'mac)
                    (display-images-p)
                    (image-type-available-p 'xbm)
                    (fboundp
                     'image--set-test-frame-backing-scale-factor)))
  (let* ((dir (make-temp-file "mac-image-2x-file-tests" t))
         (file (expand-file-name "t.xbm" dir))
         (frame (selected-frame))
         (old-scale
          (image--set-test-frame-backing-scale-factor frame 1))
         image)
    (unwind-protect
        (progn
          (with-temp-file file
            (insert mac-image-2x-file-tests--xbm-8x8))
          (with-temp-file (expand-file-name "t@2x.xbm" dir)
            (insert mac-image-2x-file-tests--xbm-16x16))
          (setq image (create-image file nil nil :scale 1))
          (should (equal (image-size image t) '(8 . 8))))
      (when image
        (image-flush image frame))
      (image--set-test-frame-backing-scale-factor frame old-scale)
      (delete-directory dir t))))

(provide 'mac-image-2x-file-tests)
;;; mac-image-2x-file-tests.el ends here
