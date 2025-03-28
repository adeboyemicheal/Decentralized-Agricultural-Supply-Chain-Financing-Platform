;; Repayment Tracking Contract
;; Monitors loan payments and schedules

(define-map loan-repayments
  { loan-id: uint }
  {
    principal-amount: uint,
    interest-rate: uint, ;; Basis points (1/100 of a percent)
    term-days: uint,
    total-due: uint,
    status: (string-ascii 10)
  }
)

;; Initialize loan tracking (called by loan management contract)
(define-public (initialize-loan-tracking
    (loan-id uint)
    (principal-amount uint)
    (interest-rate uint)
    (term-days uint))
  (let
    (
      (total-interest (calculate-interest principal-amount interest-rate term-days))
      (total-due (+ principal-amount total-interest))
    )
    (map-set loan-repayments
      { loan-id: loan-id }
      {
        principal-amount: principal-amount,
        interest-rate: interest-rate,
        term-days: term-days,
        total-due: total-due,
        status: "ACTIVE"
      }
    )
    (ok true)
  )
)

;; Calculate interest amount
(define-private (calculate-interest (principal uint) (rate uint) (days uint))
  ;; Interest = Principal * Rate * Time
  ;; Rate is in basis points (1/100 of a percent)
  ;; Convert to decimal by dividing by 10000 (100 * 100)
  ;; Time is in days, convert to years by dividing by 365
  (/ (* (* principal rate) days) (* u10000 u365))
)

;; Mark a loan as repaid
(define-public (mark-loan-repaid (loan-id uint))
  (let
    (
      (repayment (unwrap! (map-get? loan-repayments { loan-id: loan-id }) (err u404)))
    )
    (asserts! (is-eq (get status repayment) "ACTIVE") (err u1))

    (map-set loan-repayments
      { loan-id: loan-id }
      (merge repayment { status: "REPAID" })
    )
    (ok true)
  )
)

;; Mark a loan as defaulted
(define-public (mark-loan-defaulted (loan-id uint))
  (let
    (
      (repayment (unwrap! (map-get? loan-repayments { loan-id: loan-id }) (err u404)))
    )
    (asserts! (is-eq (get status repayment) "ACTIVE") (err u1))

    (map-set loan-repayments
      { loan-id: loan-id }
      (merge repayment { status: "DEFAULTED" })
    )
    (ok true)
  )
)

;; Get total amount due for a loan
(define-read-only (get-total-amount-due (loan-id uint))
  (match (map-get? loan-repayments { loan-id: loan-id })
    repayment (ok (get total-due repayment))
    (err u404)
  )
)

;; Get loan repayment status
(define-read-only (get-repayment-status (loan-id uint))
  (match (map-get? loan-repayments { loan-id: loan-id })
    repayment (ok (get status repayment))
    (err u404)
  )
)

;; Get loan repayment details
(define-read-only (get-repayment-details (loan-id uint))
  (map-get? loan-repayments { loan-id: loan-id })
)
