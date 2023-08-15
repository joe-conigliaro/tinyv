module util

// TODO: remove workaround once fixed in compiler
struct SharedIntWorkaround {
pub mut:
	value int
}

pub struct WorkerPool[T, Y] {
mut:
	workers   []thread
	queue_len shared SharedIntWorkaround
	ch_in     chan T
	ch_out    chan Y
}

pub fn WorkerPool.new[T, Y](mut ch_in chan T, mut ch_out chan Y) &WorkerPool[T, Y] {
	return &WorkerPool[T, Y]{
		ch_in: ch_in
		ch_out: ch_out
	}
}

pub fn (mut wp WorkerPool[T,Y]) add_worker(t thread) {
	wp.workers << t
}

pub fn (mut wp WorkerPool[T, Y]) active_jobs() int {
	return lock wp.queue_len {
		wp.queue_len.value
	}
}

pub fn (mut wp WorkerPool[T, Y]) job_done() {
	lock wp.queue_len {
		wp.queue_len.value--
	}
}

pub fn (mut wp WorkerPool[T, Y]) queue_job(job T) {
	wp.ch_in <- job
	lock wp.queue_len {
		wp.queue_len.value++
	}
}

pub fn (mut wp WorkerPool[T, Y]) queue_jobs(jobs []T) {
	for job in jobs {
		wp.queue_job(job)
	}
}

pub fn (mut wp WorkerPool[T, Y]) wait_for_results() []Y {
	mut results := []Y{}
	for wp.active_jobs() > 0 {
		result := <-wp.ch_out
		wp.job_done()
		results << result
	}

	wp.ch_in.close()
	wp.ch_out.close()
	wp.workers.wait()

	return results
}
