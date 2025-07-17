(define-constant ERR-NOT-AUTHORIZED (err u100))
(define-constant ERR-INVALID-PERCENTAGE (err u101))
(define-constant ERR-NO-HEIRS (err u102))
(define-constant ERR-MAX-HEIRS-REACHED (err u103))
(define-constant ERR-HEIR-NOT-FOUND (err u104))
(define-constant ERR-ALREADY-HEIR (err u105))
(define-constant ERR-INVALID-BLOCKS (err u106))

(define-constant MAX-HEIRS u5)
(define-constant PERCENTAGE-POINTS u10000)

(define-data-var contract-owner principal tx-sender)
(define-data-var last-activity uint stacks-block-height)
(define-data-var inactivity-blocks uint u52560)
(define-data-var total-heirs uint u0)

(define-map heirs 
    principal 
    {share: uint, index: uint}
)

(define-read-only (get-owner)
    (var-get contract-owner)
)

(define-read-only (get-last-activity)
    (var-get last-activity)
)

(define-read-only (get-inactivity-period)
    (var-get inactivity-blocks)
)

(define-read-only (get-heir-info (heir principal))
    (map-get? heirs heir)
)

(define-read-only (get-total-heirs)
    (var-get total-heirs)
)

(define-read-only (is-heir (address principal))
    (is-some (map-get? heirs address))
)

(define-read-only (check-inactive)
    (let (
        (current-height stacks-block-height)
        (last-active (var-get last-activity))
        (inactive-period (var-get inactivity-blocks))
    )
    (>= (- current-height last-active) inactive-period))
)

(define-public (update-activity)
    (begin
        (asserts! (is-eq tx-sender (var-get contract-owner)) ERR-NOT-AUTHORIZED)
        (var-set last-activity stacks-block-height)
        (ok true)
    )
)

(define-public (set-inactivity-period (blocks uint))
    (begin
        (asserts! (is-eq tx-sender (var-get contract-owner)) ERR-NOT-AUTHORIZED)
        (asserts! (> blocks u0) ERR-INVALID-BLOCKS)
        (var-set inactivity-blocks blocks)
        (ok true)
    )
)

(define-public (add-heir (heir principal) (share uint))
    (begin
        (asserts! (is-eq tx-sender (var-get contract-owner)) ERR-NOT-AUTHORIZED)
        (asserts! (<= share PERCENTAGE-POINTS) ERR-INVALID-PERCENTAGE)
        (asserts! (< (var-get total-heirs) MAX-HEIRS) ERR-MAX-HEIRS-REACHED)
        (asserts! (not (is-heir heir)) ERR-ALREADY-HEIR)
        
        (map-set heirs heir {
            share: share,
            index: (var-get total-heirs)
        })
        (var-set total-heirs (+ (var-get total-heirs) u1))
        (ok true)
    )
)

(define-public (remove-heir (heir principal))
    (begin
        (asserts! (is-eq tx-sender (var-get contract-owner)) ERR-NOT-AUTHORIZED)
        (asserts! (is-heir heir) ERR-HEIR-NOT-FOUND)
        (map-delete heirs heir)
        (var-set total-heirs (- (var-get total-heirs) u1))
        (ok true)
    )
)

(define-public (update-heir-share (heir principal) (new-share uint))
    (begin
        (asserts! (is-eq tx-sender (var-get contract-owner)) ERR-NOT-AUTHORIZED)
        (asserts! (<= new-share PERCENTAGE-POINTS) ERR-INVALID-PERCENTAGE)
        (asserts! (is-heir heir) ERR-HEIR-NOT-FOUND)
        
        (let ((heir-data (unwrap! (map-get? heirs heir) ERR-HEIR-NOT-FOUND)))
            (map-set heirs heir {
                share: new-share,
                index: (get index heir-data)
            })
        )
        (ok true)
    )
)

(define-public (claim-inheritance)
    (let (
        (is-inactive (check-inactive))
        (heir-data (map-get? heirs tx-sender))
        (contract-balance (stx-get-balance (as-contract tx-sender)))
    )
        (asserts! is-inactive ERR-NOT-AUTHORIZED)
        (asserts! (is-some heir-data) ERR-HEIR-NOT-FOUND)
        
        (let (
            (heir-share (get share (unwrap! heir-data ERR-HEIR-NOT-FOUND)))
            (amount-to-transfer (/ (* contract-balance heir-share) PERCENTAGE-POINTS))
        )
            (as-contract
                (stx-transfer? amount-to-transfer tx-sender tx-sender)
            )
        )
    )
)

(define-public (transfer-ownership (new-owner principal))
    (begin
        (asserts! (is-eq tx-sender (var-get contract-owner)) ERR-NOT-AUTHORIZED)
        (var-set contract-owner new-owner)
        (ok true)
    )
)
