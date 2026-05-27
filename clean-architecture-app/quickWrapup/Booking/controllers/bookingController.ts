// interfaces/http/BookingController.ts
class BookingController {
  constructor(private bookTicket: BookTicketUseCase) {}

  async book(req: Request, res: Response): Promise<void> {
    try {
      // validate HTTP input (controller responsibility)
      const { concertId, seatNumber } = req.body
      if (!concertId || !seatNumber) {
        res.status(400).json({ error: "Missing required fields" })
        return
      }

      // delegate to use case — no business logic here
      const output = await this.bookTicket.execute({
        concertId,
        seatNumber,
        userId: req.user.id,  // from AuthMiddleware
      })

      res.status(201).json({ data: output })
    } catch (err) {
      if (err instanceof Error)
        res.status(422).json({ error: err.message })
    }
  }
}