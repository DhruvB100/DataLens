import './App.css'
import Dashboard from './Dashboard'
import Ask from './Ask'

function App() {

  return (
    <>
      <h1>DataLens</h1>
      <section>
        <h2>Dashboard</h2>
        <Dashboard />
      </section>
      <section>
        <h2>Ask</h2>
        <Ask />
      </section>

    </>
  )
}

export default App
