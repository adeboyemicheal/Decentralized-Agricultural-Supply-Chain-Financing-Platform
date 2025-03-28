;; Crop Verification Contract
;; Validates existence and condition of agricultural products

(define-data-var last-verification-id uint u0)

;; Crop verification data structure
(define-map crop-verifications
  { verification-id: uint }
  {
    farmer: principal,
    crop-type: (string-ascii 30),
    quantity: uint,
    quality-grade: (string-ascii 2),
    location: (string-ascii 50),
    verification-date: uint,
    verifier: principal,
    status: (string-ascii 10)
  }
)

;; Approved verifiers who can validate crops
(define-map approved-verifiers
  { verifier: principal }
  { active: bool }
)

;; Initialize contract with admin
(define-data-var contract-admin principal tx-sender)

;; Add a verifier (only admin)
(define-public (add-verifier (verifier principal))
  (begin
    (asserts! (is-eq tx-sender (var-get contract-admin)) (err u403))
    (ok (map-set approved-verifiers { verifier: verifier } { active: true }))
  )
)

;; Remove a verifier (only admin)
(define-public (remove-verifier (verifier principal))
  (begin
    (asserts! (is-eq tx-sender (var-get contract-admin)) (err u403))
    (ok (map-set approved-verifiers { verifier: verifier } { active: false }))
  )
)

;; Check if a principal is an approved verifier
(define-read-only (is-approved-verifier (verifier principal))
  (default-to
    false
    (get active (map-get? approved-verifiers { verifier: verifier }))
  )
)

;; Register a new crop for verification
(define-public (register-crop
    (crop-type (string-ascii 30))
    (quantity uint)
    (location (string-ascii 50)))
  (let
    (
      (new-id (+ (var-get last-verification-id) u1))
      (current-time (unwrap-panic (get-block-info? time (- block-height u1))))
    )
    (asserts! (> quantity u0) (err u1))

    (var-set last-verification-id new-id)
    (map-set crop-verifications
      { verification-id: new-id }
      {
        farmer: tx-sender,
        crop-type: crop-type,
        quantity: quantity,
        quality-grade: "NA", ;; Not yet verified
        location: location,
        verification-date: u0, ;; Not yet verified
        verifier: tx-sender, ;; Placeholder until verified
        status: "PENDING"
      }
    )
    (ok new-id)
  )
)

;; Verify a crop (only approved verifiers)
(define-public (verify-crop
    (verification-id uint)
    (quality-grade (string-ascii 2)))
  (let
    (
      (verification (unwrap! (map-get? crop-verifications { verification-id: verification-id }) (err u404)))
      (current-time (unwrap-panic (get-block-info? time (- block-height u1))))
    )
    (asserts! (is-approved-verifier tx-sender) (err u403))
    (asserts! (is-eq (get status verification) "PENDING") (err u2))

    (map-set crop-verifications
      { verification-id: verification-id }
      (merge verification {
        quality-grade: quality-grade,
        verification-date: current-time,
        verifier: tx-sender,
        status: "VERIFIED"
      })
    )
    (ok true)
  )
)

;; Reject a crop verification (only approved verifiers)
(define-public (reject-crop (verification-id uint))
  (let
    (
      (verification (unwrap! (map-get? crop-verifications { verification-id: verification-id }) (err u404)))
      (current-time (unwrap-panic (get-block-info? time (- block-height u1))))
    )
    (asserts! (is-approved-verifier tx-sender) (err u403))
    (asserts! (is-eq (get status verification) "PENDING") (err u2))

    (map-set crop-verifications
      { verification-id: verification-id }
      (merge verification {
        verification-date: current-time,
        verifier: tx-sender,
        status: "REJECTED"
      })
    )
    (ok true)
  )
)

;; Get verification details
(define-read-only (get-verification (verification-id uint))
  (map-get? crop-verifications { verification-id: verification-id })
)

;; Check if a verification is valid
(define-read-only (is-verification-valid (verification-id uint))
  (match (map-get? crop-verifications { verification-id: verification-id })
    verification (is-eq (get status verification) "VERIFIED")
    false
  )
)
