(require 'package)

;;
;;==============  PACKAGES  ============== 
;;

(add-to-list 'package-archives '("org" . "http://orgmode.org/elpa/"))
(add-to-list 'package-archives '("melpa" . "http://melpa.org/packages/"))
(add-to-list 'package-archives '("melpa-stable" . "http://stable.melpa.org/packages/"))

(setq package-enable-at-startup nil)
(package-initialize)

;;
;; Custom
;;
(custom-set-variables
 ;; custom-set-variables was added by Custom.
 ;; If you edit it by hand, you could mess it up, so be careful.
 ;; Your init file should contain only one such instance.
 ;; If there is more than one, they won't work right.
 '(custom-safe-themes
   (quote
    ("c1f841d3e12150713efb3833afa37eb6c9bca8ec4c9e55aa1e5e740fe47c1c98" default)))
 '(package-selected-packages (quote (helm use-package evil-visual-mark-mode))))
(custom-set-faces
 ;; custom-set-faces was added by Custom.
 ;; If you edit it by hand, you could mess it up, so be careful.
 ;; Your init file should contain only one such instance.
 ;; If there is more than one, they won't work right.
 )

;;
;; Installed Packages
;;
(defvar my-packages
  '(helm page-break-lines dashboard beacon clojure-mode cider
    rainbow-delimiters company) 
  "A list of packages to ensure are installed at launch.")

;; installs all packages in my-packages
(dolist (p my-packages)
  (when (not (package-installed-p p))
    (package-install p)))

;; required features
(require 'helm-config)
(require 'page-break-lines)

(use-package dashboard
  :config
  (dashboard-setup-startup-hook))

(use-package rainbow-delimiters
  :config
  (add-hook 'prog-mode-hook #'rainbow-delimiters-mode))

(use-package company
  :config
  (add-hook 'after-init-hook 'global-company-mode))

;; Clojure
;;  - leiningen path
(add-to-list 'exec-path "/Users/mpcarolin/bin/")
(use-package clojure-mode)
(use-package cider)

;;
;; =================== THEMES ====================
;;
;; To avoid polluting emacs.d, specify themes to install in a custom subdir
;; and all of its recursive children
(let ((basedir "~/.emacs.d/themes/"))
    (dolist (f (directory-files basedir))
    (if (and (not (or (equal f ".") (equal f "..")))
		(file-directory-p (concat basedir f)))
	(add-to-list 'custom-theme-load-path (concat basedir f)))))

;; my selected theme for startup
(load-theme 'firewatch)

;;
;; ================ GUI SETTINGS =================
;;

;; Hide the toolbar
(tool-bar-mode -1)

;; Show line numbers
(global-linum-mode t)

;; Make line numbers more visible (light grey)
(set-face-foreground 'linum "#989d9e")

;;
;; ================ KEY BINDINGS =================
;;

;; scroll up and down in company-mode using M- and vim keys
(global-set-key (kbd "M-j") 'company-select-next)
(global-set-key (kbd "M-k") 'company-select-previous)

;; switch to previous buffer
(global-set-key (kbd "M-b") 'mode-line-other-buffer)


;; close current window (in addition to C-x 0)
(global-set-key (kbd "M-w") 'delete-window)

;; switch to other window (in addition to C-ww)
(global-set-key [C-tab] 'other-window)

;; ------=== Helm override bindings ===---------
;; find-files
(global-set-key (kbd "C-x C-f") 'helm-find-files)

;; launch command (don't forget C-z for docs inline!)
(global-set-key (kbd "M-x") 'helm-M-x)

;;
;; ============== VARIABLE BINDINGS ==============
;;
;; remove cursor from inactive windows
(setq-default cursor-in-non-selected-windows nil)
	     
;; EVIL MODE!
(require 'evil)
(evil-mode t)
