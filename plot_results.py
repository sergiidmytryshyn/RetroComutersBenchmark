import pandas as pd
import matplotlib.pyplot as plt

def generate_benchmark_plots(csv_filepath="all_resuults.csv"):
    df = pd.read_csv(csv_filepath)
    
    df = df.rename(columns={'Unnamed: 6': 'Seconds', 'FramesSeconds': 'Frames'})

    clean_rows = []
    current_bench = None

    for index, row in df.iterrows():
        run_val = str(row['Run']).strip()
        
        if run_val in ['Power', 'Sqrt', 'Str']:
            current_bench = run_val
            
        if current_bench is None:
            continue
            
        row_data = row.to_dict()
        row_data['Benchmark'] = current_bench
        clean_rows.append(row_data)

    clean_df = pd.DataFrame(clean_rows)

    clean_df['Loops'] = pd.to_numeric(clean_df['Loops'])
    clean_df['Seconds'] = pd.to_numeric(clean_df['Seconds'])

    benchmarks = ['Power', 'Sqrt', 'Str']
    
    for bench in benchmarks:
        bench_data = clean_df[clean_df['Benchmark'] == bench]
        
        if bench_data.empty:
            continue
            
        plt.figure(figsize=(10, 6))
        
        machines = bench_data['Machine'].unique()
        
        for machine in machines:
            machine_data = bench_data[bench_data['Machine'] == machine]
            
            agg_data = machine_data.groupby('Loops')['Seconds'].mean().reset_index()
            
            agg_data = agg_data.sort_values('Loops')
            
            plt.plot(agg_data['Loops'], agg_data['Seconds'], marker='o', label=machine)
        
        plt.title(f'Benchmark: {bench} - Time vs Loops')
        plt.xlabel('Number of Loops')
        plt.ylabel('Time (Seconds)')
        plt.legend()
        plt.grid(True, linestyle='--', alpha=0.7)
        plt.tight_layout()
        
        plt.savefig(f"{bench.lower()}_benchmark.png")
        plt.show()

if __name__ == "__main__":
    generate_benchmark_plots()