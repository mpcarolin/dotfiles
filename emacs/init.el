(require 'package)

;;
;;==============  PACKAGES  ============== 
;;

(add-to-list 'package-archives '("org" . "http://orgmode.org/elpa/"))
(add-to-list 'package-archives '("melpa" . "http://melp-lefta.org/packages/"))
(add-to-list 'package-archives '("melpa-stable" . "http://stable.melpa.org/packages/"))
(add-to-list 'package-archives '("marmalade" . "https://marmalade-repo.org/packages/"))


(setq package-enable-at-startup nil)
(package-initialize)

;;
;; Installed Packages
;;
(defvar my-packages
  '(helm page-break-lines dashboard beacon clojure-mode cider
	 rainbow-delimiters company all-the-icons neotree
	 doom-themes solaire-mode powerline buffer-move
	 projectile flx-ido ido-vertical-mode perspective
	 which-key use-package cl-lib) 
  "A list of packages to ensure are installed at launch.")

;; installs all packages in my-packages
(dolist (p my-packages)
  (when (not (package-installed-p p))
    (package-install p)))

(eval-when-compile
  (require 'use-package))


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
    ("a94f1a015878c5f00afab321e4fef124b2fc3b823c8ddd89d360d710fc2bddfc" "b59d7adea7873d58160d368d42828e7ac670340f11f36f67fa8071dbf957236a" "c1f841d3e12150713efb3833afa37eb6c9bca8ec4c9e55aa1e5e740fe47c1c98" default)))
 '(package-selected-packages
   (quote
    (which-key perspective ido-vertical-mode flx-ido projectile helm use-package evil-visual-mark-mode))))
(custom-set-faces
 ;; custom-set-faces was added by Custom.
 ;; If you edit it by hand, you could mess it up, so be careful.
 ;; Your init file should contain only one such instance.
 ;; If there is more than one, they won't work right.
 )


;; required features
(require 'helm-config)
(require 'page-break-lines)
(require 'ido-vertical-mode)

(use-package flx-ido)
(use-package all-the-icons) ;; on fresh install, run M-x all-the-icons-install-fonts after installing all-the-icons
(use-package solaire-mode) ;; config in theme section
(use-package buffer-move)

(use-package powerline
  :config
  (powerline-default-theme)) 

(use-package neotree
  :config
  (add-hook 'neotree-mode-hook
	    (lambda ()
	      (define-key evil-normal-state-local-map (kbd "RET") 'neotree-enter)
	      (define-key evil-normal-state-local-map (kbd "q") 'neotree-hide)
	      (define-key evil-normal-state-local-map (kbd "SPC") 'neotree-quick-look))))

(use-package hlinum)

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
;;(load-theme 'firewatch)

;;;; DOOM Theme
(require 'doom-themes)

;; Global settings (defaults)
(setq doom-themes-enable-bold t    ; if nil, bold is universally disabled
      doom-themes-enable-italic t) ; if nil, italics is universally disabled

;; Load the theme (doom-one, doom-molokai, etc); keep in mind that each theme
;; may have their own settings.
(load-theme 'doom-vibrant t)

;; Enable flashing mode-line on errors
(doom-themes-visual-bell-config)

;; Enable custom neotree theme
(doom-themes-neotree-config)  ; all-the-icons fonts must be installed!

;; Corrects (and improves) org-mode's native fontification.
(doom-themes-org-config)

;;;; SOLAIRE (brightening sidebar and whatnot)
;; brighten buffers (that represent real files)
(add-hook 'after-change-major-mode-hook #'turn-on-solaire-mode)
;; To enable solaire-mode unconditionally for certain modes:
(add-hook 'ediff-prepare-buffer-hook #'solaire-mode)

;; ...if you use auto-revert-mode, this prevents solaire-mode from turning
;; itself off every time Emacs reverts the file
(add-hook 'after-revert-hook #'turn-on-solaire-mode)

;; highlight the minibuffer when it is activated:
(add-hook 'minibuffer-setup-hook #'solaire-mode-in-minibuffer)

;; if the bright and dark background colors are the wrong way around, use this
;; to switch the backgrounds of the `default` and `solaire-default-face` faces.
;; This should be used *after* you load the active theme!
;;
;; NOTE: This is necessary for themes in the doom-themes package!
(solaire-mode-swap-bg)

;;
;; ================ GUI SETTINGS =================
;;

;; Hide the toolbar
(tool-bar-mode -1)

;; Hide scroll bar
(toggle-scroll-bar -1)

;; Show line numbers ONLY in programming buffers
(add-hook 'prog-mode-hook 'linum-mode)

;;
;; ================ KEY BINDINGS =================
;;

;; create new windows
(global-set-key (kbd "M-n") 'split-window-right)
(global-set-key (kbd "C-M-n") 'split-window-below)

;; buffer move (shift around windows)
(global-set-key (kbd "C-M-h") 'buf-move-left)
(global-set-key (kbd "C-M-l") 'buf-move-right)
(global-set-key (kbd "C-M-k") 'buf-move-up)
(global-set-key (kbd "C-M-j") 'buf-move-down)

;; wind move to match vim keys with meta
(global-set-key (kbd "M-h") 'windmove-left)
(global-set-key (kbd "M-l") 'windmove-right)
(global-set-key (kbd "M-k") 'windmove-up)
(global-set-key (kbd "M-j") 'windmove-down)

;; scroll up and down in company-mode using C- and vim keys
(global-set-key (kbd "C-j") 'company-select-next)
(global-set-key (kbd "C-k") 'company-select-previous)

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

;; neotree
(global-set-key (kbd "M-t") 'neotree-toggle)

;;
;; ============== VARIABLE BINDINGS ==============
;;
;; remove cursor from inactive windows
(setq-default cursor-in-non-selected-windows nil)
(setq-default major-mode 'org-mode)
	     
;;
;; ================ MODE DEFAULTS ================
;;

(global-hl-line-mode 1)

;; Enable which-key
(which-key-mode)

;; Enable projectile
(projectile-global-mode +1)

;;;; IDO Mode 
(ido-mode 1)
(setq ido-enable-flex-matching t)

;; IDO Vertical config
(ido-vertical-mode 1)
(setq ido-vertical-define-keys 'C-n-and-C-p-only)

;;;; EVIL MODE!
(add-to-list 'load-path "~/.emacs.d/evil")
(require 'evil)
(evil-mode t)

