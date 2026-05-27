// application/booking/BookTicketUseCase.ts
class BookTicketUseCase {
  constructor(
    private concertRepo: ConcertRepository,   // port
    private bookingRepo: BookingRepository,   // port
    private paymentGw:  PaymentGateway,      // port
    private outboxRepo: OutboxRepository,    // port
    private txManager:  TransactionManager   // port
  ) {}

  async execute(input: BookTicketInput): Promise<BookTicketOutput> {
    const booking = await this.txManager.run(async (tx) => {
      // load aggregates
      const concert = await this.concertRepo.findById(input.concertId, tx)
      if (!concert) throw new Error("Concert not found")

      // domain does all the thinking
      const seat = new SeatNumber(input.seatNumber)
      concert.reserveSeat(seat, input.userId)  // throws if invalid

      // charge payment (still inside tx)
      await this.paymentGw.charge(input.userId, concert.price, tx)

      // create booking aggregate
      const booking = Booking.create(concert.id, seat, input.userId)

      // persist + save events in ONE tx
      await Promise.all([
        this.concertRepo.save(concert, tx),
        this.bookingRepo.save(booking, tx),
        this.outboxRepo.saveEvents([...concert.pullEvents(), ...booking.pullEvents()], tx),
      ])
      return booking  // → COMMIT
    })                  // → ROLLBACK if anything throws

    return { bookingId: booking.id, status: booking.status }
  }
}