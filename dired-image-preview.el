;;; dired-image-preview.el --- Preview images at point in Dired -*- lexical-binding: t -*-
;; Version: 0.1
;; Package-Requires: ((emacs "27.1"))
;; Keywords: files, dired, images
;; URL: https://github.com/laluxx/dired-image-preview

;;; Commentary:
;; This package provides a minor mode for Dired that displays a preview
;; of image files at point.  It supports various image formats including
;; PNG, JPG, GIF, and SVG.
;; TODO animate GIF

;;; Code:
(require 'dired)

(defgroup dired-image-preview nil
  "Preview images at point in Dired."
  :group 'dired)

;; Customization options
(defcustom dired-image-preview-scale 0.5
  "Scale factor for image previews."
  :type 'float
  :group 'dired-image-preview)

(defcustom dired-image-preview-delay 0.2
  "Delay in seconds before showing preview when using auto-preview."
  :type 'float
  :group 'dired-image-preview)

(defcustom dired-image-preview-spacing 1
  "Number of newlines before and after the preview."
  :type 'integer
  :group 'dired-image-preview)

(defcustom dired-image-preview-auto-remove t
  "Whether to automatically remove previews when moving to a different file."
  :type 'boolean
  :group 'dired-image-preview)

(defcustom dired-image-preview-max-width nil
  "Maximum width of preview in pixels. nil means no limit."
  :type '(choice (const :tag "No limit" nil)
                 (integer :tag "Max width in pixels"))
  :group 'dired-image-preview)

(defcustom dired-image-preview-max-height nil
  "Maximum height of preview in pixels. nil means no limit."
  :type '(choice (const :tag "No limit" nil)
                 (integer :tag "Max height in pixels"))
  :group 'dired-image-preview)

(defcustom dired-image-preview-auto-mode nil
  "Whether to automatically preview images when moving cursor."
  :type 'boolean
  :group 'dired-image-preview)

(defcustom dired-image-preview-excluded-extensions '("ico" "cur")
  "List of image extensions to exclude from preview."
  :type '(repeat string)
  :group 'dired-image-preview)

;; Internal variables
(defvar-local dired-image-preview-overlays nil
  "List of overlays used to display image previews.")

(defvar-local dired-image-preview-timer nil
  "Timer for delayed preview display.")

(defvar-local dired-image-preview-last-point nil
  "Last point position for tracking movement.")

;; Core functions
(defun dired-image-preview--should-preview-p (file)
  "Determine if FILE should be previewed based on configuration."
  (and file
       (display-images-p)
       (not (member (file-name-extension file) dired-image-preview-excluded-extensions))
       (string-match (image-file-name-regexp) file)))

(defun dired-image-preview--create-image (file)
  "Create image object for FILE with current settings."
  (let* ((type (intern (downcase (file-name-extension file))))
         (spec (list :scale dired-image-preview-scale)))
    (when dired-image-preview-max-width
      (push dired-image-preview-max-width spec)
      (push :max-width spec))
    (when dired-image-preview-max-height
      (push dired-image-preview-max-height spec)
      (push :max-height spec))
    (apply #'create-image file type nil spec)))

(defun dired-image-preview-hide-at-point ()
  "Hide the image preview at point."
  (interactive)
  (let ((pos (line-end-position)))
    (dolist (overlay dired-image-preview-overlays)
      (when (= (overlay-start overlay) pos)
        (delete-overlay overlay)
        (setq dired-image-preview-overlays 
              (delq overlay dired-image-preview-overlays))))))

(defun dired-image-preview-hide-all ()
  "Hide all image previews."
  (interactive)
  (dolist (overlay dired-image-preview-overlays)
    (delete-overlay overlay))
  (setq dired-image-preview-overlays nil))

(defun dired-image-preview-show ()
  "Show image preview at point in Dired buffer."
  (interactive)
  (let* ((file (dired-get-filename nil t)))
    (when (dired-image-preview--should-preview-p file)
      (when dired-image-preview-auto-remove
        (dired-image-preview-hide-all))
      (let* ((pos (line-end-position))
             (image (dired-image-preview--create-image file))
             (overlay (make-overlay pos pos))
             (spacing (make-string dired-image-preview-spacing ?\n)))
        (overlay-put overlay 'after-string
                     (concat spacing (propertize " " 'display image) spacing))
        (push overlay dired-image-preview-overlays)))))

(defun dired-image-preview-toggle ()
  "Toggle the image preview at point."
  (interactive)
  (let ((has-preview nil)
        (pos (line-end-position)))
    (dolist (overlay dired-image-preview-overlays)
      (when (= (overlay-start overlay) pos)
        (setq has-preview t)))
    (if has-preview
        (dired-image-preview-hide-at-point)
      (dired-image-preview-show))))

(defun dired-image-preview--auto-show ()
  "Function called when point moves in auto-preview mode."
  (when (and dired-image-preview-auto-mode
             (not (equal (point) dired-image-preview-last-point)))
    (when dired-image-preview-timer
      (cancel-timer dired-image-preview-timer))
    (setq dired-image-preview-timer
          (run-with-idle-timer
           dired-image-preview-delay nil
           (lambda ()
             (when (dired-utils-get-filename)
               (dired-image-preview-show)))))
    (setq dired-image-preview-last-point (point))))

(defun dired-image-preview--enable ()
  "Enable image preview in the current Dired buffer."
  (when dired-image-preview-auto-mode
    (add-hook 'post-command-hook #'dired-image-preview--auto-show nil t)))

(defun dired-image-preview--disable ()
  "Disable image preview in the current Dired buffer."
  (remove-hook 'post-command-hook #'dired-image-preview--auto-show t)
  (when dired-image-preview-timer
    (cancel-timer dired-image-preview-timer))
  (dired-image-preview-hide-all))

;;;###autoload
(define-minor-mode dired-image-preview-mode
  "Toggle image preview at point in Dired buffers."
  :lighter " ImgPreview"
  :group 'dired-image-preview
  (if dired-image-preview-mode
      (dired-image-preview--enable)
    (dired-image-preview--disable)))

(provide 'dired-image-preview)
;;; dired-image-preview.el ends here
