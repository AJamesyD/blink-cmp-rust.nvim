use std::collections::BTreeSet;

#[derive(Clone, Debug, Default, PartialEq, Eq, PartialOrd, Ord, Hash)]
enum Status {
    #[default]
    Pending,
    InProgress,
    Done,
}

#[derive(Clone, Debug, Default, PartialEq, Eq, PartialOrd, Ord, Hash)]
struct Task {
    title: String,
    status: Status,
    _internal_id: u64,
}

impl Task {
    fn mark_done(&mut self) {
        self.status = Status::Done;
    }

    fn description(&self) -> String {
        let check = match self.status {
            Status::Done => "x",
            _ => " ",
        };
        format!("[{check}] {}", self.title)
    }

    fn is_overdue(&self) -> bool {
        !matches!(self.status, Status::Done)
    }
}

impl std::fmt::Display for Task {
    fn fmt(&self, f: &mut std::fmt::Formatter<'_>) -> std::fmt::Result {
        write!(f, "{}", self.description())
    }
}

fn main() {
    let mut tasks = BTreeSet::new();

    let mut task = Task {
        title: "Write docs".into(),
        ..Default::default()
    };
    task.mark_done();
    tasks.insert(task.clone());

    tasks.insert(Task {
        title: "Review PR".into(),
        ..Default::default()
    });

    for task in &tasks {
        if task.is_overdue() {
            println!("{task}");
        }
    }

    // To trigger the completion menu for screenshots, type:
    //   task.       — shows methods and fields on Task
    //   Status::    — shows enum variants
}
