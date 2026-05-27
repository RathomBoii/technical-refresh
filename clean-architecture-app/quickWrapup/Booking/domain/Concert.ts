class Concert {  // ← Aggregate Root
  private seats: Map<string, Seat> = new Map()
  private status: ConcertStatus = ConcertStatus.OPEN

  // ทุก operation ต้องผ่านเมธอดของ Concert
  reserveSeat(seatNumber: string, userId: string): this {

    // Business rule #1 — ตรวจ concert
    if (this.status !== ConcertStatus.OPEN)
      throw new Error("Concert is not open")

    // Business rule #2 — ตรวจ seat
    const seat = this.seats.get(seatNumber)
    if (!seat) throw new Error("Seat not found")
    if (seat.isReserved) throw new Error("Seat already reserved")

    // Business rule #3 — ตรวจ user
    if (this.hasUserBooked(userId))
      throw new Error("User already has a booking")

    // ผ่านทุก rule แล้ว — ถึงจะ mutate ได้
    seat.reserve(userId)
    return this
    // this.events.push(new SeatReservedEvent(this.id, seatNumber))
  }

  cancelConcert(): void {
    this.status = ConcertStatus.CANCELLED
    // cancel ทุก seat ในครั้งเดียว — consistent เสมอ
    this.seats.forEach(seat => seat.release())
  }
}