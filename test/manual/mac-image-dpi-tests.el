;;; mac-image-dpi-tests.el --- Tests for Mac high-DPI metadata images  -*- lexical-binding: t; -*-

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
;; backing scale to 1 and 2, independently of the connected display.
;; The tests exercise the ImageIO loader, so they require a build
;; whose PNG support comes from ImageIO rather than libpng.
;;
;; They also need `image--set-test-frame-backing-scale-factor', which
;; only exists in a build configured with --enable-checking.

;;; Code:

(require 'ert)
(require 'image)

(defconst mac-image-dpi-tests--144-dpi-data
  (concat
   "iVBORw0KGgoAAAANSUhEUgAAAAoAAAAKCAIAAAACUFjqAAAACXBIWXMAABYlAAAW"
   "JQFJUiTwAAAAEklEQVR42mM4Y2yMBzGMSmNDAKCKd4kzzxnzAAAAAElFTkSuQmCC")
  "Base64-encoded 10x10 PNG image with 144-DPI pHYs metadata.")

(defun mac-image-dpi-tests--sizes-at-scales (image)
  "Return IMAGE's pixel size after forcing backing scales 1, 2, and 1."
  (let* ((frame (selected-frame))
         (old-scale
          (image--set-test-frame-backing-scale-factor frame 1)))
    (unwind-protect
        (mapcar
         (lambda (scale)
           (image--set-test-frame-backing-scale-factor frame scale)
           (image-flush image frame)
           (image-size image t))
         '(1 2 1))
      (image-flush image frame)
      (image--set-test-frame-backing-scale-factor frame old-scale))))

(ert-deftest mac-image-dpi-tests-still-size ()
  "A high-DPI metadata image keeps its halved size on scale-1 frames."
  (skip-unless (and (eq window-system 'mac)
                    (display-images-p)
                    (image-type-available-p 'png)
                    (fboundp
                     'image--set-test-frame-backing-scale-factor)))
  (let ((data (base64-decode-string mac-image-dpi-tests--144-dpi-data)))
    (should
     (equal
      (mac-image-dpi-tests--sizes-at-scales (create-image data 'png t :scale 1))
      '((5 . 5) (5 . 5) (5 . 5))))))

(ert-deftest mac-image-dpi-tests-cache-hit ()
  "Looking a high-DPI metadata image up again on a scale-1 frame hits the cache."
  (skip-unless (and (eq window-system 'mac)
                    (display-images-p)
                    (image-type-available-p 'png)
                    (fboundp
                     'image--set-test-frame-backing-scale-factor)))
  (let* ((data (base64-decode-string mac-image-dpi-tests--144-dpi-data))
         (image (create-image data 'png t :scale 1))
         (frame (selected-frame))
         (old-scale
          (image--set-test-frame-backing-scale-factor frame 1)))
    (unwind-protect
        (progn
          (image-size image t)
          (let ((cache-size (image-cache-size)))
            (image-size image t)
            (should (= (image-cache-size) cache-size))))
      (image-flush image frame)
      (image--set-test-frame-backing-scale-factor frame old-scale))))

(ert-deftest mac-image-dpi-tests-flush-drops-every-scale ()
  "One image-flush drops the copies cached for both backing scales."
  (skip-unless (and (eq window-system 'mac)
                    (display-images-p)
                    (image-type-available-p 'png)
                    (fboundp
                     'image--set-test-frame-backing-scale-factor)))
  (let* ((data (base64-decode-string mac-image-dpi-tests--144-dpi-data))
         (image (create-image data 'png t))
         (frame (selected-frame))
         (old-scale
          (image--set-test-frame-backing-scale-factor frame 1)))
    (unwind-protect
        (let ((empty-size
               (progn
                 (image--set-test-frame-backing-scale-factor frame 2)
                 (image-flush image frame)
                 (image--set-test-frame-backing-scale-factor frame 1)
                 (image-flush image frame)
                 (image-cache-size))))
          (image-size image t)
          (image--set-test-frame-backing-scale-factor frame 2)
          (image-size image t)
          (image--set-test-frame-backing-scale-factor frame 1)
          (image-flush image frame)
          (should (= (image-cache-size) empty-size)))
      (image-flush image frame)
      (image--set-test-frame-backing-scale-factor frame old-scale))))

(provide 'mac-image-dpi-tests)
;;; mac-image-dpi-tests.el ends here
