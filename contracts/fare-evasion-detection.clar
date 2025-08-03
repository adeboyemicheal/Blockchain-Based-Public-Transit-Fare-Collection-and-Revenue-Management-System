;; Fare Evasion Detection Contract
;; Identifies and addresses unauthorized transit use

;; Constants
(define-constant CONTRACT-OWNER tx-sender)
(define-constant ERR-NOT-AUTHORIZED (err u400))
(define-constant ERR-VIOLATION-NOT-FOUND (err u401))
(define-constant ERR-INVALID-PENALTY (err u402))
(define-constant ERR-ALREADY-RESOLVED (err u403))
(define-constant ERR-INVALID-APPEAL (err u404))

;; Data Variables
(define-data-var next-violation-id uint u1)
(define-data-var next-appeal-id uint u1)
(define-data-var base-penalty-amount uint u100)

;; Data Maps
(define-map evasion-violations
  uint
  {
    violator: principal,
    location: (string-ascii 50),
    violation-type: (string-ascii 30),
    penalty-amount: uint,
    timestamp: uint,
    status: (string-ascii 15),
    evidence-hash: (buff 32)
  })

(define-map user-violation-history
  principal
  {
    total-violations: uint,
    total-penalties: uint,
    repeat-offender: bool,
    last-violation: uint
  })

(define-map penalty-appeals
  uint
  {
    violation-id: uint,
    appellant: principal,
    reason: (string-ascii 200),
    status: (string-ascii 15),
    submitted-block: uint,
    reviewed-block: uint
  })

(define-map violation-types
  (string-ascii 30)
  {base-penalty: uint, escalation-factor: uint})

(define-map enforcement-officers
  principal
  {authorized: bool, violations-reported: uint})

;; Read-only functions
(define-read-only (get-violation-details (violation-id uint))
  (map-get? evasion-violations violation-id))

(define-read-only (get-user-history (user principal))
  (default-to
    {total-violations: u0, total-penalties: u0, repeat-offender: false, last-violation: u0}
    (map-get? user-violation-history user)))

(define-read-only (get-appeal-details (appeal-id uint))
  (map-get? penalty-appeals appeal-id))

(define-read-only (get-violation-type-penalty (violation-type (string-ascii 30)))
  (map-get? violation-types violation-type))

(define-read-only (is-enforcement-officer (officer principal))
  (match (map-get? enforcement-officers officer)
    officer-data (get authorized officer-data)
    false))

(define-read-only (calculate-penalty (violation-type (string-ascii 30)) (user principal))
  (let ((user-history (get-user-history user))
        (violation-data (unwrap! (get-violation-type-penalty violation-type) (err u0))))
    (let ((base-penalty (get base-penalty violation-data))
          (escalation (get escalation-factor violation-data))
          (violation-count (get total-violations user-history)))
      (if (> violation-count u2)
        (ok (+ base-penalty (* base-penalty (/ (* escalation violation-count) u100))))
        (ok base-penalty)))))

(define-read-only (get-base-penalty)
  (var-get base-penalty-amount))

;; Public functions
(define-public (authorize-enforcement-officer (officer principal))
  (begin
    (asserts! (is-eq tx-sender CONTRACT-OWNER) ERR-NOT-AUTHORIZED)
    (map-set enforcement-officers officer {authorized: true, violations-reported: u0})
    (ok true)))

(define-public (revoke-enforcement-authorization (officer principal))
  (begin
    (asserts! (is-eq tx-sender CONTRACT-OWNER) ERR-NOT-AUTHORIZED)
    (match (map-get? enforcement-officers officer)
      officer-data (map-set enforcement-officers officer (merge officer-data {authorized: false}))
      true)
    (ok true)))

(define-public (set-violation-type-penalty (violation-type (string-ascii 30)) (base-penalty uint) (escalation-factor uint))
  (begin
    (asserts! (is-eq tx-sender CONTRACT-OWNER) ERR-NOT-AUTHORIZED)
    (map-set violation-types violation-type {base-penalty: base-penalty, escalation-factor: escalation-factor})
    (ok true)))

(define-public (report-violation (violator principal) (location (string-ascii 50)) (violation-type (string-ascii 30)) (evidence-hash (buff 32)))
  (let ((violation-id (var-get next-violation-id))
        (penalty-amount (unwrap! (calculate-penalty violation-type violator) ERR-INVALID-PENALTY))
        (user-history (get-user-history violator)))
    (begin
      (asserts! (is-enforcement-officer tx-sender) ERR-NOT-AUTHORIZED)
      (map-set evasion-violations violation-id {
        violator: violator,
        location: location,
        violation-type: violation-type,
        penalty-amount: penalty-amount,
        timestamp: block-height,
        status: "pending",
        evidence-hash: evidence-hash
      })
      (map-set user-violation-history violator {
        total-violations: (+ (get total-violations user-history) u1),
        total-penalties: (+ (get total-penalties user-history) penalty-amount),
        repeat-offender: (> (get total-violations user-history) u2),
        last-violation: block-height
      })
      (match (map-get? enforcement-officers tx-sender)
        officer-data (map-set enforcement-officers tx-sender
                       (merge officer-data {violations-reported: (+ (get violations-reported officer-data) u1)}))
        true)
      (var-set next-violation-id (+ violation-id u1))
      (ok violation-id))))

(define-public (resolve-violation (violation-id uint) (resolution (string-ascii 15)))
  (let ((violation-data (unwrap! (get-violation-details violation-id) ERR-VIOLATION-NOT-FOUND)))
    (begin
      (asserts! (is-eq tx-sender CONTRACT-OWNER) ERR-NOT-AUTHORIZED)
      (asserts! (is-eq (get status violation-data) "pending") ERR-ALREADY-RESOLVED)
      (map-set evasion-violations violation-id (merge violation-data {status: resolution}))
      (ok true))))

(define-public (submit-appeal (violation-id uint) (reason (string-ascii 200)))
  (let ((violation-data (unwrap! (get-violation-details violation-id) ERR-VIOLATION-NOT-FOUND))
        (appeal-id (var-get next-appeal-id)))
    (begin
      (asserts! (is-eq tx-sender (get violator violation-data)) ERR-NOT-AUTHORIZED)
      (asserts! (is-eq (get status violation-data) "pending") ERR-INVALID-APPEAL)
      (map-set penalty-appeals appeal-id {
        violation-id: violation-id,
        appellant: tx-sender,
        reason: reason,
        status: "submitted",
        submitted-block: block-height,
        reviewed-block: u0
      })
      (var-set next-appeal-id (+ appeal-id u1))
      (ok appeal-id))))

(define-public (review-appeal (appeal-id uint) (approved bool))
  (let ((appeal-data (unwrap! (get-appeal-details appeal-id) ERR-INVALID-APPEAL))
        (violation-data (unwrap! (get-violation-details (get violation-id appeal-data)) ERR-VIOLATION-NOT-FOUND)))
    (begin
      (asserts! (is-eq tx-sender CONTRACT-OWNER) ERR-NOT-AUTHORIZED)
      (asserts! (is-eq (get status appeal-data) "submitted") ERR-ALREADY-RESOLVED)
      (map-set penalty-appeals appeal-id (merge appeal-data {
        status: (if approved "approved" "rejected"),
        reviewed-block: block-height
      }))
      (if approved
        (map-set evasion-violations (get violation-id appeal-data)
          (merge violation-data {status: "dismissed"}))
        true)
      (ok approved))))

(define-public (pay-penalty (violation-id uint))
  (let ((violation-data (unwrap! (get-violation-details violation-id) ERR-VIOLATION-NOT-FOUND)))
    (begin
      (asserts! (is-eq tx-sender (get violator violation-data)) ERR-NOT-AUTHORIZED)
      (asserts! (is-eq (get status violation-data) "pending") ERR-ALREADY-RESOLVED)
      (map-set evasion-violations violation-id (merge violation-data {status: "paid"}))
      (ok (get penalty-amount violation-data)))))

(define-public (set-base-penalty (amount uint))
  (begin
    (asserts! (is-eq tx-sender CONTRACT-OWNER) ERR-NOT-AUTHORIZED)
    (var-set base-penalty-amount amount)
    (ok true)))

;; Initialize default violation types
(map-set violation-types "no-ticket" {base-penalty: u100, escalation-factor: u50})
(map-set violation-types "expired-ticket" {base-penalty: u75, escalation-factor: u25})
(map-set violation-types "invalid-transfer" {base-penalty: u50, escalation-factor: u30})
(map-set violation-types "zone-violation" {base-penalty: u125, escalation-factor: u40})
