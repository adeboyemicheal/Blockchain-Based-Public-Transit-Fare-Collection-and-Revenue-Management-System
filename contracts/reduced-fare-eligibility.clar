;; Reduced Fare Eligibility Verification Contract
;; Validates discounts for seniors, students, and low-income riders

;; Constants
(define-constant CONTRACT-OWNER tx-sender)
(define-constant ERR-NOT-AUTHORIZED (err u200))
(define-constant ERR-INVALID-CATEGORY (err u201))
(define-constant ERR-EXPIRED-ELIGIBILITY (err u202))
(define-constant ERR-ALREADY-VERIFIED (err u203))
(define-constant ERR-INVALID-DISCOUNT (err u204))

;; Data Variables
(define-data-var next-application-id uint u1)
(define-data-var verification-fee uint u25)

;; Data Maps
(define-map eligibility-status
  principal
  {
    category: (string-ascii 20),
    discount-rate: uint,
    expiry-block: uint,
    verified: bool,
    verification-date: uint
  })

(define-map discount-rates
  (string-ascii 20)
  {rate: uint, duration-blocks: uint})

(define-map verification-applications
  uint
  {
    applicant: principal,
    category: (string-ascii 20),
    status: (string-ascii 15),
    submitted-block: uint,
    documents-hash: (buff 32)
  })

(define-map category-usage-stats
  (string-ascii 20)
  {total-users: uint, total-savings: uint})

;; Read-only functions
(define-read-only (get-eligibility-status (user principal))
  (map-get? eligibility-status user))

(define-read-only (get-discount-rate (category (string-ascii 20)))
  (map-get? discount-rates category))

(define-read-only (is-eligible (user principal))
  (match (get-eligibility-status user)
    eligibility (and (get verified eligibility) (> (get expiry-block eligibility) block-height))
    false))

(define-read-only (get-user-discount (user principal))
  (match (get-eligibility-status user)
    eligibility (if (and (get verified eligibility) (> (get expiry-block eligibility) block-height))
                   (some (get discount-rate eligibility))
                   none)
    none))

(define-read-only (calculate-discounted-fare (original-fare uint) (user principal))
  (match (get-user-discount user)
    discount-rate (ok (- original-fare (/ (* original-fare discount-rate) u100)))
    (ok original-fare)))

(define-read-only (get-application-details (app-id uint))
  (map-get? verification-applications app-id))

(define-read-only (get-category-stats (category (string-ascii 20)))
  (default-to {total-users: u0, total-savings: u0} (map-get? category-usage-stats category)))

;; Public functions
(define-public (set-discount-rate (category (string-ascii 20)) (rate uint) (duration-blocks uint))
  (begin
    (asserts! (is-eq tx-sender CONTRACT-OWNER) ERR-NOT-AUTHORIZED)
    (asserts! (<= rate u100) ERR-INVALID-DISCOUNT)
    (map-set discount-rates category {rate: rate, duration-blocks: duration-blocks})
    (ok true)))

(define-public (apply-for-eligibility (category (string-ascii 20)) (documents-hash (buff 32)))
  (let ((app-id (var-get next-application-id))
        (rate-info (unwrap! (get-discount-rate category) ERR-INVALID-CATEGORY)))
    (begin
      (map-set verification-applications app-id {
        applicant: tx-sender,
        category: category,
        status: "pending",
        submitted-block: block-height,
        documents-hash: documents-hash
      })
      (var-set next-application-id (+ app-id u1))
      (ok app-id))))

(define-public (verify-eligibility (app-id uint) (approved bool))
  (let ((app-data (unwrap! (get-application-details app-id) ERR-INVALID-CATEGORY)))
    (let ((applicant (get applicant app-data))
          (category (get category app-data))
          (rate-info (unwrap! (get-discount-rate category) ERR-INVALID-CATEGORY)))
      (begin
        (asserts! (is-eq tx-sender CONTRACT-OWNER) ERR-NOT-AUTHORIZED)
        (asserts! (is-eq (get status app-data) "pending") ERR-ALREADY-VERIFIED)
        (if approved
          (begin
            (map-set eligibility-status applicant {
              category: category,
              discount-rate: (get rate rate-info),
              expiry-block: (+ block-height (get duration-blocks rate-info)),
              verified: true,
              verification-date: block-height
            })
            (map-set verification-applications app-id (merge app-data {status: "approved"}))
            (let ((current-stats (get-category-stats category)))
              (map-set category-usage-stats category {
                total-users: (+ (get total-users current-stats) u1),
                total-savings: (get total-savings current-stats)
              })))
          (map-set verification-applications app-id (merge app-data {status: "rejected"})))
        (ok approved)))))

(define-public (renew-eligibility (documents-hash (buff 32)))
  (let ((current-status (unwrap! (get-eligibility-status tx-sender) ERR-INVALID-CATEGORY)))
    (let ((category (get category current-status))
          (rate-info (unwrap! (get-discount-rate category) ERR-INVALID-CATEGORY)))
      (begin
        (asserts! (get verified current-status) ERR-INVALID-CATEGORY)
        (let ((app-id (var-get next-application-id)))
          (map-set verification-applications app-id {
            applicant: tx-sender,
            category: category,
            status: "renewal",
            submitted-block: block-height,
            documents-hash: documents-hash
          })
          (var-set next-application-id (+ app-id u1))
          (ok app-id))))))

(define-public (record-discount-usage (user principal) (savings-amount uint))
  (let ((user-status (unwrap! (get-eligibility-status user) ERR-INVALID-CATEGORY)))
    (let ((category (get category user-status)))
      (begin
        (asserts! (is-eligible user) ERR-EXPIRED-ELIGIBILITY)
        (let ((current-stats (get-category-stats category)))
          (map-set category-usage-stats category {
            total-users: (get total-users current-stats),
            total-savings: (+ (get total-savings current-stats) savings-amount)
          }))
        (ok true)))))

(define-public (revoke-eligibility (user principal))
  (begin
    (asserts! (is-eq tx-sender CONTRACT-OWNER) ERR-NOT-AUTHORIZED)
    (match (get-eligibility-status user)
      current-status (begin
                      (map-set eligibility-status user (merge current-status {verified: false}))
                      (ok true))
      ERR-INVALID-CATEGORY)))

(define-public (set-verification-fee (fee uint))
  (begin
    (asserts! (is-eq tx-sender CONTRACT-OWNER) ERR-NOT-AUTHORIZED)
    (var-set verification-fee fee)
    (ok true)))

;; Initialize default discount rates
(map-set discount-rates "senior" {rate: u50, duration-blocks: u52560}) ;; ~1 year
(map-set discount-rates "student" {rate: u30, duration-blocks: u26280}) ;; ~6 months
(map-set discount-rates "low-income" {rate: u40, duration-blocks: u52560}) ;; ~1 year
(map-set discount-rates "disabled" {rate: u60, duration-blocks: u105120}) ;; ~2 years
