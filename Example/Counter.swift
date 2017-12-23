class CounterViewController: UIViewController {
    @IBOutlet weak var label: UILabel?
    @IBOutlet weak var minus: UIButton?
    @IBOutlet weak var plus: UIButton?
    
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        typealias State = Int
        typealias CounterSystem = System<State, Event, CounterError, Context>
        typealias CounterUserAction = UserAction<State, Event, CounterError, Context>
        typealias CounterFeedback = Feedback<State, Event, CounterError, Context>
        
        enum Event {
            case increment
            case decrement
        }
        
        struct Context {
            
        }
        
        enum CounterError: Error {
            case generic
        }
        
        let tapPlus = CounterUserAction.init(trigger: Event.increment)
        let tapMinus = CounterUserAction.init(trigger: Event.decrement)
        
        @IBAction func plusButtonTapped(_ sender: Any) {
            tapPlus.execute()
        }
        
        @IBAction func minusButtonTapped(_ sender: Any) {
            tapMinus.execute()
        }
        
        let bindUI:(State) ->() = { state in
            self.label?.text = String(state)
        }
        
        CounterSystem.pure(
            initialState: 0,
            context: Context(),
            reducer: { (state, event) -> State in
                switch event {
                case .increment:
                    return state + 1
                case .decrement:
                    return state - 1
                }
        },
            uiBindings: [bindUI],
            userActions: [tapPlus,tapMinus],
            feedback: []
        )
    }
}
