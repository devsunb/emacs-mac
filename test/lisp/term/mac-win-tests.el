;;; mac-win-tests.el --- tests for mac-win.el  -*- lexical-binding: t -*-

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


;;; Code:

(require 'ert)
(require 'cl-lib)
(load (expand-file-name "../lisp/term/mac-win.el"
			(getenv "EMACS_TEST_DIRECTORY"))
      nil nil)

;; Loading mac-win.el installs global hooks; the tests below call the
;; functions directly, so keep this process unhooked.
(remove-hook 'emacs-startup-hook #'mac-daemon-initialize-window-system)
(remove-hook 'delete-frame-functions #'mac-abort-minibuffer-on-deleted-frame)
(remove-hook 'after-delete-frame-functions
	     #'mac-abort-minibuffer-after-delete-frame)

(ert-deftest mac-win-daemon-warm-up-frame-starts-transparent ()
  (let ((frame-alpha-lower-limit 20)
	make-frame-parameters
	make-frame-alpha-lower-limit
	set-frame-parameter-calls)
    (cl-letf (((symbol-function 'make-frame)
	       (lambda (parameters)
		 (setq make-frame-parameters parameters
		       make-frame-alpha-lower-limit frame-alpha-lower-limit)
		 'warm-up-frame))
	      ((symbol-function 'set-frame-parameter)
	       (lambda (frame parameter value)
		 (push (list frame parameter value)
		       set-frame-parameter-calls)))
	      ((symbol-function 'select-frame) #'ignore)
	      ((symbol-function 'redisplay) #'ignore)
	      ((symbol-function 'delete-frame) #'ignore))
      (mac-daemon-warm-up-first-frame))
    (should (eq (alist-get 'window-system make-frame-parameters) 'mac))
    (should (equal (alist-get 'alpha make-frame-parameters) 0))
    ;; The frame must be created while `frame-alpha-lower-limit' is 0,
    ;; or mac_set_frame_alpha clamps (alpha . 0) up to the default 0.2.
    (should (= make-frame-alpha-lower-limit 0))
    (should (member '(warm-up-frame alpha 0)
		    set-frame-parameter-calls))))

(defun mac-win-tests--hide-dock-icon (frames)
  "Run `mac-daemon-hide-dock-icon' with FRAMES as the frame list.
Each element of FRAMES has the form (FRAME TYPE VISIBLE), the values
`framep' and `frame-visible-p' return for FRAME.  Return a cons of
whether the activation policy was prohibited and whether the warm-up ran."
  (let (prohibited warmed)
    (cl-letf (((symbol-function 'framep)
	       (lambda (frame) (nth 1 (assq frame frames))))
	      ((symbol-function 'frame-visible-p)
	       (lambda (frame) (nth 2 (assq frame frames))))
	      ((symbol-function 'filtered-frame-list)
	       (lambda (predicate)
		 (seq-filter predicate (mapcar #'car frames))))
	      ((symbol-function 'mac--set-activation-policy-prohibited)
	       (lambda () (setq prohibited t)))
	      ((symbol-function 'mac-daemon-warm-up-first-frame)
	       (lambda () (setq warmed t))))
      (mac-daemon-hide-dock-icon))
    (cons prohibited warmed)))

(ert-deftest mac-win-daemon-hide-dock-icon-prohibits-when-warm-up-disabled ()
  (let ((mac-daemon-warm-up nil))
    (should (equal (mac-win-tests--hide-dock-icon
		    '((invisible-mac-frame mac nil)
		      (visible-tty-frame t t)))
		   '(t . nil)))))

(ert-deftest mac-win-daemon-hide-dock-icon-warms-up-when-enabled ()
  (let ((mac-daemon-warm-up t))
    (should (equal (mac-win-tests--hide-dock-icon
		    '((invisible-mac-frame mac nil)))
		   '(nil . t)))))

(ert-deftest mac-win-daemon-hide-dock-icon-skips-with-visible-frame ()
  (let ((mac-daemon-warm-up t))
    (should (equal (mac-win-tests--hide-dock-icon
		    '((visible-mac-frame mac t)))
		   '(nil . nil)))))

(ert-deftest mac-win-daemon-without-session-stops-resolving-mac-display ()
  (let ((display-format-alist (copy-sequence display-format-alist))
	(initialized-p (get 'mac 'window-system-initialized))
	initialized)
    (unwind-protect
	(progn
	  (put 'mac 'window-system-initialized nil)
	  (should (eq (window-system-for-display "Mac") 'mac))
	  (cl-letf (((symbol-function 'daemonp) (lambda () t))
		    ((symbol-function 'mac--window-server-available-p)
		     (lambda () nil))
		    ((symbol-function 'window-system-initialization)
		     (lambda (&rest _) (setq initialized t))))
	    (mac-daemon-initialize-window-system))
	  (should-not initialized)
	  (should-not (window-system-for-display "Mac")))
      (put 'mac 'window-system-initialized initialized-p))))

(ert-deftest mac-win-daemon-apple-event-creates-usable-frame ()
  (let (make-frame-parameters selected-frame)
    (cl-letf (((symbol-function 'daemonp) (lambda () t))
	      ((symbol-function 'selected-frame)
	       (lambda () 'initial-frame))
	      ((symbol-function 'framep)
	       (lambda (frame)
		 (if (eq frame 'invisible-mac-frame) 'mac t)))
	      ((symbol-function 'frame-parent) (lambda (_frame) nil))
	      ((symbol-function 'frame-visible-p)
	       (lambda (frame) (not (eq frame 'invisible-mac-frame))))
	      ((symbol-function 'filtered-frame-list)
	       (lambda (predicate)
		 (and (funcall predicate 'invisible-mac-frame)
		      '(invisible-mac-frame))))
	      ((symbol-function 'make-frame)
	       (lambda (parameters)
		 (setq make-frame-parameters parameters)
		 'new-mac-frame))
	      ((symbol-function 'select-frame)
	       (lambda (frame &optional _norecord)
		 (setq selected-frame frame))))
      (mac-ae-select-frame-for-open))
    (should (eq selected-frame 'new-mac-frame))
    (should (eq (alist-get 'window-system make-frame-parameters) 'mac))
    (should (eq (alist-get 'client make-frame-parameters) 'nowait))))

(ert-deftest mac-win-daemon-warm-up-cleans-up-after-frame-hook-error ()
  (let ((frame-alpha-lower-limit 20)
	(created-frame nil)
	(deleted-frame nil)
	(failing-hook (lambda (_frame) (error "Hook failed"))))
    (unwind-protect
	(progn
	  (add-hook 'after-make-frame-functions failing-hook)
	  (cl-letf (((symbol-function 'make-frame)
		     (lambda (_parameters)
		       (setq created-frame 'warm-up-frame)
		       (run-hook-with-args 'after-make-frame-functions
					   created-frame)
		       created-frame))
		    ((symbol-function 'frame-live-p)
		     (lambda (frame) (eq frame created-frame)))
		    ((symbol-function 'set-frame-parameter) #'ignore)
		    ((symbol-function 'delete-frame)
		     (lambda (frame &optional _force)
		       (setq deleted-frame frame))))
	    (should-error (mac-daemon-warm-up-first-frame))))
      (remove-hook 'after-make-frame-functions failing-hook))
    (should (eq deleted-frame created-frame))
    (should (= frame-alpha-lower-limit 20))))

(defun mac-win-tests--abort-minibuffer-after-delete (deleted remaining)
  "Run the minibuffer abort pair for DELETED with REMAINING frames left.
DELETED and each element of REMAINING have the form
\(FRAME TYPE VISIBLE), the values `framep' and `frame-visible-p'
return for FRAME.  Return a cons of whether the deletion was recorded
and the function scheduled with `run-at-time'."
  (let* ((mac-minibuffer-deleted-frames nil)
	 (frames (cons deleted remaining))
	 (frame (car deleted))
	 recorded scheduled)
    (cl-letf (((symbol-function 'framep)
	       (lambda (f) (nth 1 (assq f frames))))
	      ((symbol-function 'active-minibuffer-window)
	       (lambda () 'minibuffer-window))
	      ((symbol-function 'window-frame)
	       (lambda (_window) frame))
	      ((symbol-function 'frame-list)
	       (lambda () (mapcar #'car remaining)))
	      ((symbol-function 'frame-visible-p)
	       (lambda (f) (nth 2 (assq f frames))))
	      ((symbol-function 'run-at-time)
	       (lambda (_time _repeat function &rest _args)
		 (setq scheduled function))))
      (mac-abort-minibuffer-on-deleted-frame frame)
      (setq recorded (and (assq frame mac-minibuffer-deleted-frames) t))
      (setq scheduled nil)
      (mac-abort-minibuffer-after-delete-frame frame)
      (should-not (assq frame mac-minibuffer-deleted-frames)))
    (cons recorded scheduled)))

(ert-deftest mac-win-daemon-abort-minibuffer-without-visible-frame ()
  "Only a visible Mac frame can host the stranded minibuffer.
An invisible Mac frame and a visible frame of another type both fail to
keep the minibuffer reachable."
  (should (equal (mac-win-tests--abort-minibuffer-after-delete
		  '(deleted-mac-frame mac t)
		  '((invisible-mac-frame mac nil)
		    (visible-tty-frame t t)))
		 '(t . top-level))))

(ert-deftest mac-win-daemon-keep-minibuffer-with-iconified-frame ()
  "A minimized Mac frame still counts as a host for the minibuffer."
  (should (equal (mac-win-tests--abort-minibuffer-after-delete
		  '(deleted-mac-frame mac t)
		  '((invisible-mac-frame mac nil)
		    (iconified-mac-frame mac icon)))
		 '(t . nil))))

(ert-deftest mac-win-daemon-ignore-minibuffer-on-deleted-non-mac-frame ()
  "Deleting a frame of another type records nothing, so nothing aborts."
  (should (equal (mac-win-tests--abort-minibuffer-after-delete
		  '(deleted-tty-frame t t)
		  '((invisible-mac-frame mac nil)))
		 '(nil . nil))))

(ert-deftest mac-win-daemon-open-restores-minimized-frame ()
  "A daemon Apple event must not open into a minimized frame."
  (let ((visibility '((sel . icon)))
	restored selected)
    (cl-letf (((symbol-function 'daemonp) (lambda () t))
	      ((symbol-function 'selected-frame) (lambda () 'sel))
	      ((symbol-function 'framep) (lambda (_frame) 'mac))
	      ((symbol-function 'frame-parent) (lambda (_frame) nil))
	      ((symbol-function 'frame-visible-p)
	       (lambda (frame) (alist-get frame visibility)))
	      ((symbol-function 'filtered-frame-list)
	       (lambda (predicate)
		 (seq-filter predicate (mapcar #'car visibility))))
	      ((symbol-function 'make-frame-visible)
	       (lambda (frame) (setq restored frame)))
	      ((symbol-function 'make-frame)
	       (lambda (&optional _parameters)
		 (error "Unexpected make-frame")))
	      ((symbol-function 'select-frame)
	       (lambda (frame &optional _norecord) (setq selected frame))))
      (mac-ae-select-frame-for-open))
    (should (eq restored 'sel))
    (should (eq selected 'sel))))

(provide 'mac-win-tests)

;;; mac-win-tests.el ends here
