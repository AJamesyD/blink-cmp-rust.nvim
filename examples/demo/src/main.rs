#[derive(Clone, Debug, Default, PartialEq, Eq, Hash, PartialOrd, Ord)]
struct Task {
    title: String,
    done: bool,
    _internal_id: u64,
}

#[allow(unused)]
enum Status {
    Pending,
    InProgress,
    Done,
}

impl Task {
    #[allow(unused)]
    fn mark_done(&mut self) {
        self.done = true;
    }

    fn description(&self) -> String {
        format!("[{}] {}", if self.done { "x" } else { " " }, self.title)
    }

    #[allow(unused)]
    fn is_overdue(&self) -> bool {
        !self.done
    }
}

impl std::fmt::Display for Task {
    fn fmt(&self, f: &mut std::fmt::Formatter<'_>) -> std::fmt::Result {
        write!(f, "{}", self.description())
    }
}

fn main() {
    #[allow(unused)]
    let mut task = Task {
        title: "Write docs".into(),
        ..Default::default()
    };

    // UNCOMMENT: task.

    // UNCOMMENT: let s: Status = Status::
}
