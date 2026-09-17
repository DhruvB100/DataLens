import { useState, useEffect} from "react";
import { API_BASE } from "./api";
import { BarChart, Bar, XAxis,YAxis, Tooltip, ResponsiveContainer } from "recharts";

// bar chart + table, fetches its own data on mount, no props needed
export default function Dashboard() {
    // loading/error state is separate per section
    const [stats,setStats] = useState([])
    const [statsLoading,setStatsLoading] = useState(true)
    const [statsError, setStatsError] = useState(null)

    useEffect(() => {
        fetch(`${API_BASE}/stats`)
            .then(res => res.json())
            .then(data => {
                // api returns numbers as strings (athena thing) - convert or the chart breaks
                const cleaned_data = data.map(row => {
                    return {
                        ...row,
                        num_events: Number(row.num_events),
                        avg_magnitude: Number(row.avg_magnitude)
                    };
                });

                setStats(cleaned_data);
            })
            .catch(() => setStatsError("Couldn't load chart data"))
            .finally(() => setStatsLoading(false));
    }, []);

    const [largest,setLargest] = useState([])
    const [largestLoading,setLargestLoading] = useState(true)
    const [largestError,setLargestError] = useState(null)

    useEffect(() => {
        fetch(`${API_BASE}/largest?limit=10`)
            .then(res => res.json())
            .then(data => {
                const cleaned_data = data.map(row => {
                    return {
                        ...row,
                        magnitude: Number(row.magnitude),
                        depth_km: Number(row.depth_km)
                    };
                });
            setLargest(cleaned_data);
            })
            .catch(() => setLargestError("Couldn't load table data"))
            .finally(() => setLargestLoading(false));
    }, []);

    return (
        <div style={{padding: "20px"}}>
            <h3>Earthquakes per day</h3>
            {statsLoading ? (
                <p>Loading chart info...</p>
            ): statsError ? (
                <p style={{ color: "red" }}>{statsError}</p>
            ): (
                <ResponsiveContainer width="100%" height={300}>
                    <BarChart data={stats}>
                        <XAxis dataKey="dt" />
                        <YAxis />
                        <Tooltip />

                        <Bar dataKey="num_events" fill="#8884d8" />
            
                    </BarChart>
                </ResponsiveContainer>
            )}

            <h3>Largest Recent Earthquakes</h3>
            {largestLoading ? (
                <p>Loading table info</p>
            ): largestError ?(
                <p style={{ color: "red" }}>{largestError}</p>
            ):(
                // scrolls horizontally on narrow screens instead of squishing columns
                // or overflowing the whole page
                <div style={{overflowX:"auto"}}>
                    <table>
                        <thead>
                            <tr>
                                <th>Place</th>
                                <th>Magnitude</th>
                                <th>Depth (km)</th>
                                <th>Time</th>
                            </tr>
                        </thead>
                        <tbody>
                            {largest.map(row => {
                                return (
                                    <tr key ={row.id}>
                                        <td>{row.place}</td>
                                        <td>{row.magnitude.toFixed(1)}</td>
                                        <td>{row.depth_km.toFixed(1)}</td>
                                        <td>{row.event_time}</td>
                                    </tr>
                                );
                            })}
                        </tbody>
                    </table>
                </div>
            )}
        </div>
    );
}