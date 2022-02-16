;;; fannypack.el --- They say it's back in style -*- lexical-binding: t; -*-

;; Copyright (C) 2022  Theodor Thornhill

;; Author: Theodor Thornhill <theo@thornhill.no>
;; Keywords: tools languages
;; Version: 0.1
;; Package-Requires: ((emacs "27.2") (project "0.8.1"))

;; This program is free software; you can redistribute it and/or modify
;; it under the terms of the GNU General Public License as published by
;; the Free Software Foundation, either version 3 of the License, or
;; (at your option) any later version.

;; This program is distributed in the hope that it will be useful,
;; but WITHOUT ANY WARRANTY; without even the implied warranty of
;; MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
;; GNU General Public License for more details.

;; You should have received a copy of the GNU General Public License
;; along with this program.  If not, see <https://www.gnu.org/licenses/>.

;;; Commentary:

;; A fannypack is a persisted list of paths that are considered important for
;; the ongoing work.  Thus, we rely on git branch names to distinguish between
;; fannypacks.  The use case is as follows:
;;
;; * Create a branch and start the ongoing work.
;; * Discover what files are important, place them in a fannypack.
;; * When exploring the code base in the current project, you can more easily now
;;   jump to the important files, thus saving time.
;; * Realize you need to work on a different branch - switch to it.
;;   Now the fannypack is automatically scoped to the new branch.
;;   If there are files there, jump to them.

;;; Code:

(require 'vc-git)

(defgroup fannypack nil
  "You cannot leave your house without your fannypack."
  :group 'tools)

(defcustom fannypack-directory
  (concat user-emacs-directory ".local/fannypack/")
  "Where the fannypacks will be saved."
  :type 'string)

(defun fannypack--ensure-directory ()
  (make-directory (file-truename fannypack-directory) t))

(defun fannypack--name ()
  (cl-flet* ((normalize (file-name)
               (string-replace "/" "---" file-name)))
    (file-truename
     (concat fannypack-directory
             (concat
              (normalize (project-root (project-current)))
              "#"
              (normalize (car (vc-git-branches))))))))

(defun fannypack--read-fannypack ()
  (let* ((filename (fannypack--name)))
    (when (file-exists-p filename)
      (with-temp-buffer
        (insert-file-contents filename)
        (read (current-buffer))))))

(defun fannypack--write-fannypack (fannypack)
  (let ((filename (fannypack--name)))
    (with-temp-buffer
      (insert ";;; -*- lisp-data -*-\n")
      (let ((print-length nil)
            (print-level nil))
        (pp fannypack (current-buffer)))
      (write-region nil nil filename nil 'silent))))

(defun fannypack--completing-read (prompt fannypack)
  (let ((default (caar fannypack)))
    (if fannypack
        (completing-read
         (format prompt (file-name-nondirectory default))
         fannypack nil t nil nil default)
      (user-error "Fannypack empty!"))))

;;;###autoload
(defun fannypack-place ()
  (interactive)
  (fannypack--ensure-directory)
  (let ((fannypack (fannypack--read-fannypack)))
    (unless (member (list buffer-file-name) fannypack)
      (push (list buffer-file-name) fannypack)
      (fannypack--write-fannypack fannypack)
      (message "Placed in fannypack!"))))

;;;###autoload
(defun fannypack-pick ()
  (interactive)
  (when-let ((choice
              (fannypack--completing-read
               "Fannypack pick [%s]: "
               (remove (list buffer-file-name)
                       (fannypack--read-fannypack)))))
    (find-file choice)))

;;;###autoload
(defun fannypack-drop ()
  (interactive)
  (when-let* ((fannypack (fannypack--read-fannypack))
              (element
               (list
                (fannypack--completing-read
                 "Fannypack drop [%s]: "
                 fannypack))))
    (setq fannypack (remove element fannypack))
    (fannypack--write-fannypack fannypack)
    (message "Dropped %s from fannypack"
             (file-name-nondirectory (car element)))))

;;;###autoload
(defun fannypack-promote ()
  (interactive)
  (let* ((fannypack (fannypack--read-fannypack))
         (element-to-move
          (list
           (fannypack--completing-read
            "Fannypack promote [%s]: "
            fannypack))))
    (setq fannypack (remove element-to-move fannypack))
    (push element-to-move fannypack)
    (fannypack--write-fannypack fannypack)
    (message "Promoted %s to top in fannypack"
             (file-name-nondirectory (car element-to-move)))))

;;;###autoload
(defun fannypack-demote ()
  (interactive)
  (let* ((fannypack (fannypack--read-fannypack))
         (element-to-move
          (list
           (fannypack--completing-read
            "Fannypack demote [%s]: "
            fannypack))))
    (setq fannypack (remove element-to-move fannypack))
    (setq fannypack (append fannypack (list element-to-move)))
    (fannypack--write-fannypack fannypack)
    (message "Demoted %s to bottom in fannypack"
             (file-name-nondirectory (car element-to-move)))))

(provide 'fannypack)
;;; fannypack.el ends here
