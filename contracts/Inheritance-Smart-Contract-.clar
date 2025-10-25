(define-constant ERR-NOT-AUTHORIZED (err u100))
(define-constant ERR-INVALID-PERCENTAGE (err u101))
(define-constant ERR-NO-HEIRS (err u102))
(define-constant ERR-MAX-HEIRS-REACHED (err u103))
(define-constant ERR-HEIR-NOT-FOUND (err u104))
(define-constant ERR-ALREADY-HEIR (err u105))
(define-constant ERR-INVALID-BLOCKS (err u106))
(define-constant ERR-EMERGENCY-ACTIVE (err u107))
(define-constant ERR-ALREADY-VOTED (err u108))
(define-constant ERR-EMERGENCY-NOT-ACTIVE (err u109))
(define-constant ERR-VESTING-NOT-UNLOCKED (err u110))
(define-constant ERR-VESTING-ALREADY-CLAIMED (err u111))
(define-constant ERR-MAX-VESTING-SCHEDULES (err u112))

(define-constant MAX-HEIRS u5)
(define-constant PERCENTAGE-POINTS u10000)
(define-constant EMERGENCY-VOTING-BLOCKS u2628)
(define-constant EMERGENCY-THRESHOLD u6667)
(define-constant EMERGENCY-TIMEOUT-BLOCKS u5256)
(define-constant MAX-VESTING-SCHEDULES u10)

(define-data-var contract-owner principal tx-sender)
(define-data-var last-activity uint stacks-block-height)
(define-data-var inactivity-blocks uint u52560)
(define-data-var total-heirs uint u0)
(define-data-var emergency-voting-start uint u0)
(define-data-var emergency-votes uint u0)
(define-data-var vesting-schedule-count uint u0)

(define-map heirs 
    principal 
    {share: uint, index: uint}
)

(define-map emergency-voters
    principal
    bool
)

(define-map vesting-schedules
    uint
    {beneficiary: principal, amount: uint, unlock-height: uint, claimed: bool}
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

(define-read-only (get-emergency-votes)
    (var-get emergency-votes)
)

(define-read-only (get-emergency-voting-start)
    (var-get emergency-voting-start)
)

(define-read-only (is-emergency-active)
    (let (
        (voting-start (var-get emergency-voting-start))
        (current-height stacks-block-height)
    )
    (and (> voting-start u0) 
         (< (- current-height voting-start) EMERGENCY-VOTING-BLOCKS))))

(define-read-only (is-emergency-expired)
    (let (
        (voting-start (var-get emergency-voting-start))
        (current-height stacks-block-height)
    )
    (and (> voting-start u0)
         (>= (- current-height voting-start) EMERGENCY-TIMEOUT-BLOCKS))))

(define-read-only (has-voted-emergency (voter principal))
    (default-to false (map-get? emergency-voters voter))
)

(define-read-only (get-vesting-schedule (schedule-id uint))
    (map-get? vesting-schedules schedule-id)
)

(define-read-only (get-vesting-schedule-count)
    (var-get vesting-schedule-count)
)

(define-read-only (is-vesting-unlocked (schedule-id uint))
    (match (map-get? vesting-schedules schedule-id)
        schedule (>= stacks-block-height (get unlock-height schedule))
        false
    )
)

(define-public (update-activity)
    (begin
        (asserts! (is-eq tx-sender (var-get contract-owner)) ERR-NOT-AUTHORIZED)
        (var-set last-activity stacks-block-height)
        (var-set emergency-voting-start u0)
        (var-set emergency-votes u0)
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
        (asserts! (not (is-eq new-owner (var-get contract-owner))) ERR-INVALID-PERCENTAGE)
        (var-set contract-owner new-owner)
        (ok true)
    )
)

(define-public (initiate-emergency-recovery)
    (begin
        (asserts! (is-heir tx-sender) ERR-HEIR-NOT-FOUND)
        (asserts! (not (is-emergency-active)) ERR-EMERGENCY-ACTIVE)
        (if (is-emergency-expired)
            (begin
                (var-set emergency-voting-start u0)
                (var-set emergency-votes u0)
            )
            true
        )
        (var-set emergency-voting-start stacks-block-height)
        (var-set emergency-votes u0)
        (ok true)
    )
)

(define-public (vote-emergency-recovery)
    (begin
        (asserts! (is-heir tx-sender) ERR-HEIR-NOT-FOUND)
        (asserts! (is-emergency-active) ERR-EMERGENCY-NOT-ACTIVE)
        (asserts! (not (has-voted-emergency tx-sender)) ERR-ALREADY-VOTED)
        
        (map-set emergency-voters tx-sender true)
        (var-set emergency-votes (+ (var-get emergency-votes) u1))
        (ok true)
    )
)

(define-public (claim-emergency-inheritance)
    (let (
        (current-votes (var-get emergency-votes))
        (total-heir-count (var-get total-heirs))
        (voting-threshold (/ (* total-heir-count EMERGENCY-THRESHOLD) PERCENTAGE-POINTS))
        (heir-data (map-get? heirs tx-sender))
        (contract-balance (stx-get-balance (as-contract tx-sender)))
        (voting-start (var-get emergency-voting-start))
        (current-height stacks-block-height)
    )
        (asserts! (is-emergency-active) ERR-EMERGENCY-NOT-ACTIVE)
        (asserts! (>= current-votes voting-threshold) ERR-NOT-AUTHORIZED)
        (asserts! (>= (- current-height voting-start) EMERGENCY-VOTING-BLOCKS) ERR-NOT-AUTHORIZED)
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

(define-public (reset-expired-emergency)
    (begin
        (asserts! (is-emergency-expired) ERR-EMERGENCY-NOT-ACTIVE)
        (var-set emergency-voting-start u0)
        (var-set emergency-votes u0)
        (ok true)
    )
)

(define-public (create-vesting-schedule (beneficiary principal) (amount uint) (unlock-height uint))
    (let (
        (schedule-id (var-get vesting-schedule-count))
    )
        (asserts! (is-eq tx-sender (var-get contract-owner)) ERR-NOT-AUTHORIZED)
        (asserts! (< schedule-id MAX-VESTING-SCHEDULES) ERR-MAX-VESTING-SCHEDULES)
        (asserts! (> unlock-height stacks-block-height) ERR-INVALID-BLOCKS)
        (asserts! (> amount u0) ERR-INVALID-PERCENTAGE)
        (asserts! (not (is-eq beneficiary (var-get contract-owner))) ERR-INVALID-PERCENTAGE)
        
        (map-set vesting-schedules schedule-id {
            beneficiary: beneficiary,
            amount: amount,
            unlock-height: unlock-height,
            claimed: false
        })
        (var-set vesting-schedule-count (+ schedule-id u1))
        (ok schedule-id)
    )
)

(define-public (claim-vesting (schedule-id uint))
    (let (
        (schedule-count (var-get vesting-schedule-count))
        (schedule (unwrap! (map-get? vesting-schedules schedule-id) ERR-HEIR-NOT-FOUND))
        (beneficiary (get beneficiary schedule))
        (amount (get amount schedule))
        (unlock-height (get unlock-height schedule))
        (claimed (get claimed schedule))
    )
        (asserts! (< schedule-id schedule-count) ERR-HEIR-NOT-FOUND)
        (asserts! (is-eq tx-sender beneficiary) ERR-NOT-AUTHORIZED)
        (asserts! (>= stacks-block-height unlock-height) ERR-VESTING-NOT-UNLOCKED)
        (asserts! (not claimed) ERR-VESTING-ALREADY-CLAIMED)
        
        (map-set vesting-schedules schedule-id {
            beneficiary: beneficiary,
            amount: amount,
            unlock-height: unlock-height,
            claimed: true
        })
        
        (as-contract (stx-transfer? amount tx-sender beneficiary))
    )
)
