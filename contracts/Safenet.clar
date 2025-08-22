(define-fungible-token whistleblower-token)

(define-constant contract-owner tx-sender)
(define-constant err-owner-only (err u100))
(define-constant err-not-found (err u101))
(define-constant err-already-exists (err u102))
(define-constant err-insufficient-funds (err u103))
(define-constant err-unauthorized (err u104))
(define-constant err-invalid-status (err u105))
(define-constant err-already-verified (err u106))
(define-constant err-already-resolved (err u107))

(define-data-var next-violation-id uint u1)
(define-data-var total-violations uint u0)
(define-data-var total-verified uint u0)
(define-data-var total-resolved uint u0)
(define-data-var reward-pool uint u0)

(define-map violations
  { violation-id: uint }
  {
    reporter: principal,
    company: (string-ascii 100),
    location: (string-ascii 200),
    violation-type: (string-ascii 50),
    description: (string-ascii 500),
    severity: uint,
    timestamp: uint,
    status: (string-ascii 20),
    verifier: (optional principal),
    reward-amount: uint,
    evidence-hash: (optional (buff 32))
  }
)

(define-map user-stats
  { user: principal }
  {
    total-reports: uint,
    verified-reports: uint,
    total-rewards: uint,
    reputation-score: uint
  }
)

(define-map company-violations
  { company: (string-ascii 100) }
  {
    total-violations: uint,
    verified-violations: uint,
    severity-score: uint,
    last-violation: uint
  }
)

(define-map verifiers
  { verifier: principal }
  {
    is-active: bool,
    total-verifications: uint,
    accuracy-score: uint,
    stake-amount: uint
  }
)

(define-public (initialize-contract)
  (begin
    (asserts! (is-eq tx-sender contract-owner) err-owner-only)
    (try! (ft-mint? whistleblower-token u1000000 contract-owner))
    (var-set reward-pool u1000000)
    (ok true)
  )
)

(define-public (register-verifier (stake-amount uint))
  (let
    (
      (verifier-data (default-to 
        { is-active: false, total-verifications: u0, accuracy-score: u100, stake-amount: u0 }
        (map-get? verifiers { verifier: tx-sender })
      ))
    )
    (asserts! (>= stake-amount u1000) err-insufficient-funds)
    (try! (stx-transfer? stake-amount tx-sender (as-contract tx-sender)))
    (map-set verifiers
      { verifier: tx-sender }
      {
        is-active: true,
        total-verifications: (get total-verifications verifier-data),
        accuracy-score: (get accuracy-score verifier-data),
        stake-amount: (+ (get stake-amount verifier-data) stake-amount)
      }
    )
    (ok true)
  )
)

(define-public (report-violation 
  (company (string-ascii 100))
  (location (string-ascii 200))
  (violation-type (string-ascii 50))
  (description (string-ascii 500))
  (severity uint)
  (evidence-hash (optional (buff 32)))
)
  (let
    (
      (violation-id (var-get next-violation-id))
      (current-block stacks-block-height)
      (user-data (default-to
        { total-reports: u0, verified-reports: u0, total-rewards: u0, reputation-score: u50 }
        (map-get? user-stats { user: tx-sender })
      ))
    )
    (asserts! (and (>= severity u1) (<= severity u10)) err-invalid-status)
    (asserts! (> (len company) u0) err-invalid-status)
    (asserts! (> (len description) u0) err-invalid-status)
    
    (map-set violations
      { violation-id: violation-id }
      {
        reporter: tx-sender,
        company: company,
        location: location,
        violation-type: violation-type,
        description: description,
        severity: severity,
        timestamp: stacks-block-height,
        status: "reported",
        verifier: none,
        reward-amount: u0,
        evidence-hash: evidence-hash
      }
    )
    
    (map-set user-stats
      { user: tx-sender }
      {
        total-reports: (+ (get total-reports user-data) u1),
        verified-reports: (get verified-reports user-data),
        total-rewards: (get total-rewards user-data),
        reputation-score: (get reputation-score user-data)
      }
    )
    
    (var-set next-violation-id (+ violation-id u1))
    (var-set total-violations (+ (var-get total-violations) u1))
    
    (ok violation-id)
  )
)

(define-public (verify-violation (violation-id uint) (is-valid bool))
  (let
    (
      (violation-data (unwrap! (map-get? violations { violation-id: violation-id }) err-not-found))
      (verifier-data (unwrap! (map-get? verifiers { verifier: tx-sender }) err-unauthorized))
      (reporter (get reporter violation-data))
      (company (get company violation-data))
      (severity (get severity violation-data))
      (reward-amount (if is-valid (* severity u100) u0))
      (company-data (default-to
        { total-violations: u0, verified-violations: u0, severity-score: u0, last-violation: u0 }
        (map-get? company-violations { company: company })
      ))
      (user-data (default-to
        { total-reports: u0, verified-reports: u0, total-rewards: u0, reputation-score: u50 }
        (map-get? user-stats { user: reporter })
      ))
    )
    (asserts! (get is-active verifier-data) err-unauthorized)
    (asserts! (is-eq (get status violation-data) "reported") err-already-verified)
    
    (map-set violations
      { violation-id: violation-id }
      (merge violation-data {
        status: (if is-valid "verified" "rejected"),
        verifier: (some tx-sender),
        reward-amount: reward-amount
      })
    )
    
    (map-set verifiers
      { verifier: tx-sender }
      (merge verifier-data {
        total-verifications: (+ (get total-verifications verifier-data) u1)
      })
    )
    
    (if is-valid
      (begin
        (and (> reward-amount u0) (>= (var-get reward-pool) reward-amount)
          (begin
            (try! (as-contract (ft-transfer? whistleblower-token reward-amount tx-sender reporter)))
            (var-set reward-pool (- (var-get reward-pool) reward-amount))
            true
          )
        )
        
        (map-set user-stats
          { user: reporter }
          {
            total-reports: (get total-reports user-data),
            verified-reports: (+ (get verified-reports user-data) u1),
            total-rewards: (+ (get total-rewards user-data) reward-amount),
            reputation-score: (if (> (+ (get reputation-score user-data) u5) u100) u100 (+ (get reputation-score user-data) u5))
          }
        )
        
        (map-set company-violations
          { company: company }
          {
            total-violations: (+ (get total-violations company-data) u1),
            verified-violations: (+ (get verified-violations company-data) u1),
            severity-score: (+ (get severity-score company-data) severity),
            last-violation: stacks-block-height
          }
        )
        
        (var-set total-verified (+ (var-get total-verified) u1))
      )
      true
    )
    
    (ok is-valid)
  )
)

(define-public (resolve-violation (violation-id uint) (resolution-notes (string-ascii 300)))
  (let
    (
      (violation-data (unwrap! (map-get? violations { violation-id: violation-id }) err-not-found))
    )
    (asserts! (is-eq (get status violation-data) "verified") err-invalid-status)
    (asserts! (is-eq tx-sender contract-owner) err-owner-only)
    
    (map-set violations
      { violation-id: violation-id }
      (merge violation-data { status: "resolved" })
    )
    
    (var-set total-resolved (+ (var-get total-resolved) u1))
    (ok true)
  )
)

(define-public (fund-reward-pool (amount uint))
  (begin
    (try! (ft-transfer? whistleblower-token amount tx-sender (as-contract tx-sender)))
    (var-set reward-pool (+ (var-get reward-pool) amount))
    (ok true)
  )
)

(define-public (emergency-withdraw)
  (begin
    (asserts! (is-eq tx-sender contract-owner) err-owner-only)
    (let ((pool-balance (var-get reward-pool)))
      (and (> pool-balance u0)
        (begin
          (try! (as-contract (ft-transfer? whistleblower-token pool-balance tx-sender contract-owner)))
          (var-set reward-pool u0)
          true
        )
      )
    )
    (ok true)
  )
)

(define-read-only (get-violation (violation-id uint))
  (map-get? violations { violation-id: violation-id })
)

(define-read-only (get-user-stats (user principal))
  (map-get? user-stats { user: user })
)

(define-read-only (get-company-violations (company (string-ascii 100)))
  (map-get? company-violations { company: company })
)

(define-read-only (get-verifier-info (verifier principal))
  (map-get? verifiers { verifier: verifier })
)

(define-read-only (get-contract-stats)
  {
    total-violations: (var-get total-violations),
    total-verified: (var-get total-verified),
    total-resolved: (var-get total-resolved),
    reward-pool: (var-get reward-pool),
    next-violation-id: (var-get next-violation-id)
  }
)

(define-read-only (calculate-reputation-score (user principal))
  (let
    (
      (stats (default-to
        { total-reports: u0, verified-reports: u0, total-rewards: u0, reputation-score: u50 }
        (map-get? user-stats { user: user })
      ))
      (total-reports (get total-reports stats))
      (verified-reports (get verified-reports stats))
    )
    (if (> total-reports u0)
      (+ u50 (/ (* verified-reports u50) total-reports))
      u50
    )
  )
)

(define-read-only (get-company-risk-score (company (string-ascii 100)))
  (let
    (
      (company-stats (default-to
        { total-violations: u0, verified-violations: u0, severity-score: u0, last-violation: u0 }
        (map-get? company-violations { company: company })
      ))
      (total (get verified-violations company-stats))
      (severity-avg (if (> total u0) (/ (get severity-score company-stats) total) u0))
    )
    (if (> total u0)
      (if (> (+ (* total u10) (* severity-avg u5)) u100) u100 (+ (* total u10) (* severity-avg u5)))
      u0
    )
  )
)

(define-read-only (is-violation-recent (violation-id uint))
  (match (map-get? violations { violation-id: violation-id })
    violation (< (- stacks-block-height (get timestamp violation)) u1008)
    false
  )
)
