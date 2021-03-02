;;; cmake-tools.el --- Create and build c/c++ project with cmake

;; Filename: cmake-tools.el
;; Description: Create and build c/c++ project with cmake
;; Author: xhcoding <xhcoding@163.com>
;; Copyright (C) 2018, xhcoding, all right reserved
;; Created: 2018-08-07 08:16:00
;; Version: 0.1
;; Last-Update: 2020-03-02 15:08:00
;; URL: https://github.com/xhcoding/cmake-tools
;; Keywords: cmake
;; Compatibility: GNU Emacs 26.1

;;; This file is NOT part of GNU Emacs

;;; License
;;
;; This program is free software; you can redistribute it and/or modify
;; it under the terms of the GNU General Public License as published by
;; the Free Software Foundation; either version 3, or (at your option)
;; any later version.

;; This program is distributed in the hope that it will be useful,
;; but WITHOUT ANY WARRANTY; without even the implied warranty of
;; MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
;; GNU General Public License for more details.

;; You should have received a copy of the GNU General Public License
;; along with this program; see the file COPYING.  If not, write to
;; the Free Software Foundation, Inc., 51 Franklin Street, Fifth
;; Floor, Boston, MA 02110-1301, USA.

;;; Commentary:

;;; Require
(require 'dired)
(require 'eshell)
(require 'cl)

;;; Code:
;;

;;; Custom
(defgroup cmake-tools nil
  "Manage c/c++ project with cmake."
  :group 'applications
  :prefix "cp-")

(defcustom cp-project-root-files
  '("CMakeLists.txt"    ;Cmake project file
    )
  "A list of files considered to mark the root of a cmake project."
  :group 'cmake-tools
  :type '(repeat string))

(defcustom cp-cmake-minimum-version "3.7"
  "Required Cmake minimum version."
  :group 'cmake-tools
  :type 'string)


(defcustom cp-project-build-directory "build"
  "A path relative project root path, which CMake project default build."
  :group 'cmake-tools
  :type 'string)

(defcustom cp-project-binary-directory "bin"
  "A path relative build directory saved binary files."
  :group 'cmake-tools
  :type 'string)

(defcustom cp-project-template-function 'cp-project-gen-default-template
  "A function generated `CMakeLists.txt' template."
  :group 'cmake-tools
  :type 'function)

(defcustom cp-after-new-project-hook nil
  "Hook after create new project."
  :group 'cmake-tools
  :type 'hook)

;;; Variable

(defvar cp-project-root-cache nil
  "Cached value of function `cp-project-root'.")

;;; Functions

(defun cp--absolute-build-dir()
  "Absolute build directory."
  (expand-file-name cp-project-build-directory cp-project-root-cache))


(defun cp--absolute-binary-dir()
  "Absolute binary directory."
  (expand-file-name cp-project-binary-directory (cp--absolute-build-dir)))

(defun cp-parent(path)
  "Return the parent directory of PATH.
PATH may be a file or directory and directory paths end with a slash."
  (directory-file-name (file-name-directory (directory-file-name (expand-file-name path)))))


(defun cp-project-root(dir)
  "Identify a project root in DIR by recurring top-down search for files in `cp-project-root-files'."
  (if (and cp-project-root-cache (string-match (regexp-quote cp-project-root-cache) dir))
      cp-project-root-cache
    (setq cp-project-root-cache
          (cl-some
           (lambda(f)
             (locate-dominating-file
              dir
              (lambda (dir)
                (and (file-exists-p (expand-file-name f dir))
                     (or (string-match locate-dominating-stop-dir-regexp (cp-parent dir))
                         (not (file-exists-p (expand-file-name f (cp-parent dir)))))))))
           cp-project-root-files))))

;;;TODO: Improve
(defun cp-project-gen-default-template()
  "Generate a default `CMakeLists.txt' template."
  (concat
   (format "cmake_minimum_required(VERSION %s)" cp-cmake-minimum-version)
   (format "\nset(PROJECT_NAME \"%s\")" (file-name-nondirectory (directory-file-name cp-project-root-cache)))
   (format "\nproject(${PROJECT_NAME})")
   (format "\nset(CMAKE_EXPORT_COMPILE_COMMANDS ON)")
   ))

(defun cp-project-new(dir)
  "Create a new project in DIR.
TEMPLATE is a CMakeLists.txt template. IF it is nil,
use `cp-project-gen-default-template'
instead.TEMPLATE can also be a function without argument and returning a string."
  (interactive "DDirectory: ")
  (setq cp-project-root-cache dir)
  (dired-create-directory (cp--absolute-build-dir))
  (condition-case nil
      (progn
        (let ((file (expand-file-name "CMakeLists.txt"  cp-project-root-cache)))
          (with-temp-file  file
            (insert (funcall cp-project-template-function)))
          (find-file file)
          (run-hook-with-args 'cp-after-new-project-hook)))
    (error
     (dired-delete-file cp-project-root-cache 'always)
     (setq cp-project-root-cache nil)
     (message "Create project failed!"))))

(defun cp-project-gen()
  "Generate project."
  (interactive)
  (let ((default-directory cp-project-root-cache)
        (compile-command))
    (setq compile-command
          (format "cmake -B%s -H." cp-project-build-directory))
    (call-interactively 'compile)))

(defun cp-project-cleanup()
  "Clean up build directory."
  (interactive)
  (when (yes-or-no-p (format "Delete %s?" cp-project-build-directory))
    (dired-delete-file cp-project-build-directory 'always)))

(defun cp-project-build()
  "Build project."
  (interactive)
  (let ((compile-command)
        (default-directory cp-project-root-cache))
    (setq compile-command
          (format "cmake --build %s" cp-project-build-directory))
    (call-interactively 'compile)))

;;TODO: imporve run project
(defun cp-project-run(file &optional args)
  "Run FILE with ARGS in eshell."
  (interactive
   (list
    (let ((default-directory (or
                              (cp--absolute-binary-dir)
                              default-directory)))
      (car (find-file-read-args "File: " t)))
    (read-from-minibuffer "Args: ")))
  (with-current-buffer (or (get-buffer eshell-buffer-name) (eshell))
    ;; eshell-return-to-prompt has beginning of buffer error
    (eshell-return-to-prompt)
    (insert (format "%s %s" file args))
    (eshell-send-input)))

(defun cp-project-debug(file)
  "Return the path of the FILE to be debugged."
  (interactive
   (list
    (let ((default-directory (or
                              (cp--absolute-binary-dir)
                              default-directory)))
      (car (find-file-read-args "File: " t)))))
  file)

(defun cp-project-refresh()
  "Refresh project."
  (interactive)
  (condition-case nil
      (cp-project-root default-directory)
    (error (message "project refresh failed"))))

(provide 'cmake-tools)


;;; cmake-tools.el ends here
