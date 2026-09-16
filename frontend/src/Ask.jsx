import { useState } from "react";
import { API_BASE } from "./api";

// text box -> POST /ask -> shows the answer, the sql it ran, and a results table
export default function Ask(){
    const [question,setQuestion] = useState("");
    const [result,setResult] = useState(null);
    const [loading,setLoading] = useState(false);
    const [error,setError] = useState(null);

    const handleAsk = () => {
        setLoading(true);
        setError(null);
        setResult(null);

        fetch(`${API_BASE}/ask`,{
            method: "POST",
            headers: {"Content-Type":"application/json"},
            body: JSON.stringify({question})
        })
            .then(response => {
                // fetch doesn't reject on 400/502 - only real network failures -
                // so grab ok + the body together and branch on ok below
                return response.json().then(data => {
                    return {ok: response.ok, data};
                });
            })
            .then(({ok,data}) =>{
                if (ok){
                        setResult(data);
                } else {
                    setError(data.error);
                }
            })
            .catch(err => {
                setError("Network or CORS error:" + err.message)
            })
            .finally(() => {
                setLoading(false);
            });
    };

    return (
    <div style={{ padding: "20px" }}>
        <input
            type="text"
            value={question}
            onChange={(e) => setQuestion(e.target.value)}
            placeholder="Ask a question about the data..."
            style={{ width: "300px" }}
        />
        <button type="button" onClick={handleAsk} disabled={loading}>
            {loading ? "Asking..." : "Ask"}
        </button>

        {error && <p style={{ color: "red" }}>{error}</p>}

        {result && (
            <div>
                <p>{result.answer}</p>

                <details>
                    <summary>Show SQL</summary>
                    <code>{result.sql}</code>
                </details>

                {/* columns aren't fixed like the Dashboard table - they depend on
                    whatever sql the ai wrote, so headers are built from the data itself */}
                {result.rows.length > 0 && (
                    <table>
                        <thead>
                            <tr>
                                {Object.keys(result.rows[0]).map((col) => (
                                    <th key={col}>{col}</th>
                                ))}
                            </tr>
                        </thead>
                        <tbody>
                            {result.rows.map((row, i) => (
                                <tr key={i}>
                                    {Object.values(row).map((val, j) => (
                                        <td key={j}>{val}</td>
                                    ))}
                                </tr>
                            ))}
                        </tbody>
                    </table>
                )}
            </div>
        )}
    </div>
    );
}