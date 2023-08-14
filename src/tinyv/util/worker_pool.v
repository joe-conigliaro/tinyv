module util

// TODO: remove workaround once fixed in compiler
struct SharedIntWorkaround { pub mut: value int }

pub struct WorkerPool[T,Y] {
pub mut:
	workers    []thread
	queue_len  shared SharedIntWorkaround
	ch_in      chan T
	ch_out     chan Y
}

pub fn WorkerPool.new[T,Y](mut ch_in chan T, mut ch_out chan Y) &WorkerPool[T,Y] {
	return &WorkerPool[T,Y]{
		ch_in: ch_in
		ch_out: ch_out
	}
}


pub fn (mut wp WorkerPool[T,Y]) job_done() {
	lock wp.queue_len {
		wp.queue_len.value--
	}
}

pub fn (mut wp WorkerPool[T,Y]) queue_job(job T) {
	wp.ch_in <- job
	lock wp.queue_len {
		wp.queue_len.value++
	}
}

pub fn (mut wp WorkerPool[T,Y]) queue_jobs(jobs []T) {
	for job in jobs {
		wp.queue_job(job)
	}
}


pub fn (mut wp WorkerPool[T,Y]) wait_for_results() []Y {
	mut results := []Y{}
	for {
		rlock wp.queue_len {
			if wp.queue_len.value == 0 {
				break
			}
		}
		result := <- wp.ch_out
		results << result
	}

	wp.ch_in.close()
	wp.ch_out.close()
	wp.workers.wait()

	return results
}

// pub fn (mut wp WorkerPool[T,Y,U]) spawn_workers(worker fn[T,Y](mut ch_in chan T, mut ch_out chan Y)) {
// 	mut threads := []thread{}
// 	for _ in 0..wp.nr_workers {
// 		println('spawning worker')
// 		// wp.workers << spawn worker()
// 		threads << spawn worker()
// 	}
// }

// pub fn (mut wp WorkerPool) wait() {
// 	wp.workers.wait()       
// }
