let currentIteration = 0;

export function setCurrentIteration(iteration: number) {
  currentIteration = iteration;
}

export function getCurrentIteration(): number {
  return currentIteration;
}
