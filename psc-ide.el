;;; psc-ide.el --- Minor mode for PureScript's psc-ide tool.

;; Copyright (C) 2015 The psc-ide-emacs authors

;; Author   : Erik Post <erik@shinsetsu.nl>
;;            Dmitry Bushenko <d.bushenko@gmail.com>
;;            Christoph Hegemann
;; Homepage : https://github.com/epost/psc-ide-emacs
;; Version  : 0.1.0
;; Keywords : languages
;;
;;; Code:


;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;
;; Imports

(require 'company)
(require 'psc-ide-backported)
(require 'psc-ide-protocol)

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;
;; psc-ide-mode definition

(provide 'psc-ide)

;;;###autoload
(define-minor-mode psc-ide-mode
  "psc-ide-mode definition"
  :lighter " psc-ide"
  :keymap (let ((map (make-sparse-keymap)))
            (define-key map (kbd "C-c C-s") 'psc-ide-server-start)
            (define-key map (kbd "C-c C-l") 'psc-ide-load-module)
            (define-key map (kbd "C-<SPC>") 'company-complete)
            (define-key map (kbd "C-c C-t") 'psc-ide-show-type)
            map))

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;
;; Settings, override as needed.

(defgroup psc-ide nil
  "Settings for psc-ide."
  :prefix "psc-ide-"
  :group 'psc-ide)

(defcustom psc-ide-executable "psc-ide"
  "Path to the 'psc-ide' executable."
  :group 'psc-ide
  :type  'string)

(defcustom psc-ide-server-executable "psc-ide-server"
  "Path to the 'psc-ide-server' executable."
  :group 'psc-ide
  :type  'string)

(defcustom psc-ide-completion-matcher "flex"
  "The method used for completions."
  :options '("flex" "prefix")
  :group 'psc-ide
  :type  'string)


;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;
;; Interactive.

(defun company-psc-ide-backend (command &optional arg &rest ignored)
  "The psc-ide backend for 'company-mode'."
  (interactive (list 'interactive))

  (case command
    (interactive (company-begin-backend 'company-psc-ide-backend))

    (prefix (and (eq major-mode 'purescript-mode)
                 (company-grab-symbol)
                 ;; (psc-ide-ident-at-point)
                 ))

    (candidates (psc-ide-complete-impl arg))

    (sorted t)

    (annotation (psc-ide-annotation arg))
    (meta (psc-ide-meta arg))
))

(defun psc-ide-server-start (dir-name)
  "Start 'psc-ide-server'."
  (interactive (list (read-directory-name "Project root? "
                                          (psc-ide-suggest-project-dir))))
  (psc-ide-server-start-impl dir-name)
)

(defun psc-ide-load-module (module-name)
  "Provide module to load"
  (interactive (list (read-string "Module: " (car (split-string (buffer-name) "\\.")))) )
  (psc-ide-load-module-impl module-name)
)

(defun psc-ide-complete ()
  "Complete prefix string using psc-ide."
  (interactive)
  (psc-ide-complete-impl (psc-ide-ident-at-point))
)

(defun psc-ide-show-type ()
  "Show type of the symbol under cursor"
  (interactive)
  (message (psc-ide-show-type-impl (psc-ide-ident-at-point)))
)


;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;
;; Non-interactive.

(defun psc-ide-send (cmd)
  "Send a command to psc-ide."
  (shell-command-to-string (concat "echo '" cmd "' | " psc-ide-executable))
)

(defun psc-ide-ask-project-dir ()
  "Ask psc-ide-server for the project dir."
  (psc-ide-send psc-ide-command-cwd)
)

(defun psc-ide-server-start-impl (dir-name)
  "Start psc-ide-server."
  (start-process "*psc-ide-server*" "*psc-ide-server*" psc-ide-server-executable "-d" dir-name)
)

(defun psc-ide-load-module-impl (module-name)
  "Load PureScript module and its dependencies."
  (unwrap-result (json-read-from-string
                  (psc-ide-send (psc-ide-command-load [] (list module-name)))))
  )

(defun psc-ide-complete-impl (prefix)
  "Complete."
  (mapcar
   (lambda (x)
     (let ((completion (cdr (assoc 'identifier x)))
           (type (cdr (assoc 'type x)))
           (module (cdr (assoc 'module x))))
       (add-text-properties 0 1 (list :type type :module module) completion)
       completion
       ))

   (unwrap-result (json-read-from-string
    (psc-ide-send (psc-ide-command-complete [] (matcher-flex prefix))))))
)

(defun psc-ide-show-type-impl (ident)
  "Show type."
  (let* ((resp (psc-ide-send (psc-ide-command-show-type [] ident)))
         (first-result (aref
                       (unwrap-result (json-read-from-string
                        resp) ) 0)))

    (cdr (assoc 'type first-result)))
)

(defun psc-ide-annotation (s)
  (format " (%s)" (get-text-property 0 :module s))
)

(defun psc-ide-suggest-project-dir ()
  (if (fboundp 'projectile-project-root)
      (projectile-project-root)
      (file-name-directory (buffer-file-name))))

(setq company-tooltip-align-annotations t)

(defun company-psc-ide-frontend (command)
  (case command
    (post-command (and (eq major-mode 'purescript-mode)
                       (message
                        (get-text-property 0 :type
                                           (nth company-selection company-candidates))))))
)


;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;
;; Utilities

(add-to-list 'company-backends 'company-psc-ide-backend)
(add-to-list 'company-frontends 'company-psc-ide-frontend)

;;; psc-ide.el ends here
