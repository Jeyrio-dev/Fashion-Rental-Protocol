;; Fashion Rental Protocol Contract
;; Manages rental agreements, escrow, and damage assessment for fashion items

(define-data-var next-rental-id uint u1)
(define-data-var contract-owner principal tx-sender)

(define-map rental-items uint {
  owner: principal,
  name: (string-ascii 64),
  category: (string-ascii 32),
  daily-rate: uint,
  security-deposit: uint,
  available: bool,
  condition-score: uint
})

(define-map rental-agreements uint {
  item-id: uint,
  renter: principal,
  owner: principal,
  start-time: uint,
  end-time: uint,
  total-cost: uint,
  security-deposit: uint,
  status: (string-ascii 16),
  damage-reported: bool
})

(define-map user-reputation principal {
  total-rentals: uint,
  successful-rentals: uint,
  damage-incidents: uint,
  reputation-score: uint
})

(define-map escrow-balances uint uint)

(define-constant ERR-NOT-AUTHORIZED (err u401))
(define-constant ERR-NOT-FOUND (err u404))
(define-constant ERR-ITEM-UNAVAILABLE (err u405))
(define-constant ERR-INSUFFICIENT-FUNDS (err u402))
(define-constant ERR-RENTAL-ACTIVE (err u406))

(define-public (list-rental-item
  (name (string-ascii 64))
  (category (string-ascii 32))
  (daily-rate uint)
  (security-deposit uint)
  (condition-score uint))
  (let ((item-id (var-get next-rental-id)))
    (map-set rental-items item-id {
      owner: tx-sender,
      name: name,
      category: category,
      daily-rate: daily-rate,
      security-deposit: security-deposit,
      available: true,
      condition-score: condition-score
    })
    (var-set next-rental-id (+ item-id u1))
    (ok item-id)))

(define-public (create-rental-agreement
  (item-id uint)
  (rental-days uint))
  (let ((item (unwrap! (map-get? rental-items item-id) ERR-NOT-FOUND))
        (daily-rate (get daily-rate item))
        (security-deposit (get security-deposit item))
        (total-cost (+ (* daily-rate rental-days) security-deposit))
        (rental-id (var-get next-rental-id))
        (current-block stacks-block-height))
    (asserts! (get available item) ERR-ITEM-UNAVAILABLE)
    (try! (stx-transfer? total-cost tx-sender (as-contract tx-sender)))
    (map-set rental-agreements rental-id {
      item-id: item-id,
      renter: tx-sender,
      owner: (get owner item),
      start-time: current-block,
      end-time: (+ current-block (* rental-days u144)),
      total-cost: total-cost,
      security-deposit: security-deposit,
      status: "active",
      damage-reported: false
    })
    (map-set escrow-balances rental-id total-cost)
    (map-set rental-items item-id (merge item {available: false}))
    (var-set next-rental-id (+ rental-id u1))
    (ok rental-id)))

(define-public (return-item (rental-id uint) (condition-score uint))
  (let ((agreement (unwrap! (map-get? rental-agreements rental-id) ERR-NOT-FOUND))
        (item-id (get item-id agreement))
        (item (unwrap! (map-get? rental-items item-id) ERR-NOT-FOUND))
        (original-condition (get condition-score item))
        (damage-penalty (if (< condition-score original-condition)
                          (/ (get security-deposit agreement) u2)
                          u0))
        (refund-amount (- (get security-deposit agreement) damage-penalty))
        (rental-cost (- (get total-cost agreement) (get security-deposit agreement))))
    (asserts! (is-eq (get renter agreement) tx-sender) ERR-NOT-AUTHORIZED)
    (try! (as-contract (stx-transfer? rental-cost tx-sender (get owner agreement))))
    (try! (as-contract (stx-transfer? refund-amount tx-sender tx-sender)))
    (if (> damage-penalty u0)
      (try! (as-contract (stx-transfer? damage-penalty tx-sender (get owner agreement))))
      true)
    (map-set rental-agreements rental-id (merge agreement {
      status: "completed",
      damage-reported: (> damage-penalty u0)
    }))
    (map-set rental-items item-id (merge item {
      available: true,
      condition-score: condition-score
    }))
    (map-delete escrow-balances rental-id)
    (update-user-reputation tx-sender (> damage-penalty u0))
    (ok true)))

(define-public (report-damage (rental-id uint) (damage-description (string-ascii 256)))
  (let ((agreement (unwrap! (map-get? rental-agreements rental-id) ERR-NOT-FOUND)))
    (asserts! (is-eq (get owner agreement) tx-sender) ERR-NOT-AUTHORIZED)
    (map-set rental-agreements rental-id (merge agreement {damage-reported: true}))
    (ok true)))

(define-private (update-user-reputation (user principal) (had-damage bool))
  (let ((current-rep (default-to {total-rentals: u0, successful-rentals: u0, damage-incidents: u0, reputation-score: u100}
                                 (map-get? user-reputation user)))
        (new-total (+ (get total-rentals current-rep) u1))
        (new-successful (if had-damage (get successful-rentals current-rep) (+ (get successful-rentals current-rep) u1)))
        (new-damage (if had-damage (+ (get damage-incidents current-rep) u1) (get damage-incidents current-rep)))
        (new-score (if (> new-total u0) (/ (* new-successful u100) new-total) u100)))
    (map-set user-reputation user {
      total-rentals: new-total,
      successful-rentals: new-successful,
      damage-incidents: new-damage,
      reputation-score: new-score
    })))

(define-read-only (get-rental-item (item-id uint))
  (map-get? rental-items item-id))

(define-read-only (get-rental-agreement (rental-id uint))
  (map-get? rental-agreements rental-id))

(define-read-only (get-user-reputation (user principal))
  (default-to {total-rentals: u0, successful-rentals: u0, damage-incidents: u0, reputation-score: u100}
              (map-get? user-reputation user)))

(define-read-only (calculate-rental-cost (item-id uint) (days uint))
  (let ((item (unwrap! (map-get? rental-items item-id) ERR-NOT-FOUND)))
    (ok (+ (* (get daily-rate item) days) (get security-deposit item)))))
    